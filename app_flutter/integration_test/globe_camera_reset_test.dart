import 'dart:convert';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_flutter/main.dart' as app_main;
import 'package:app_flutter/app/app.dart';
import 'package:app_flutter/core/theme/theme_controller.dart';
import 'package:app_flutter/core/theme/theme_service.dart';
import 'package:app_flutter/core/theme/text_scaler.dart';
import 'package:app_flutter/core/string_resources.dart';
import 'package:app_flutter/domain/data_source.dart';
import 'package:app_flutter/domain/data_sources/sqlite_data_source.dart';
import 'package:app_flutter/features/topology/scene_3d_viewport.dart';

Future<Database> createTestDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
  await db.execute('PRAGMA foreign_keys = ON;');

  await db.execute('CREATE TABLE properties (node_id TEXT PRIMARY KEY, data_json TEXT NOT NULL)');
  await db.execute('CREATE TABLE instances (id TEXT PRIMARY KEY, parent_node_id TEXT NOT NULL, type_name TEXT NOT NULL, data_json TEXT NOT NULL)');
  await db.execute('CREATE TABLE type_definitions (type_name TEXT PRIMARY KEY, display_name TEXT NOT NULL, icon_name TEXT NOT NULL DEFAULT "insert_drive_file")');
  await db.execute('''
    CREATE TABLE type_attributes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type_name TEXT NOT NULL REFERENCES type_definitions(type_name),
      attr_key TEXT NOT NULL,
      label TEXT NOT NULL,
      attr_type TEXT NOT NULL,
      section_label TEXT,
      section_order INTEGER NOT NULL DEFAULT 0,
      is_required INTEGER NOT NULL DEFAULT 0,
      min_value REAL,
      max_value REAL,
      pattern TEXT,
      enum_options TEXT,
      enum_display_names TEXT,
      default_value TEXT,
      input_formatters TEXT,
      UNIQUE(type_name, attr_key)
    )
  ''');
  await db.execute('''
    CREATE TABLE type_relations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      parent_type_name TEXT NOT NULL REFERENCES type_definitions(type_name),
      relation_name TEXT NOT NULL,
      child_type_name TEXT NOT NULL REFERENCES type_definitions(type_name),
      child_label TEXT NOT NULL,
      UNIQUE(parent_type_name, child_type_name)
    )
  ''');

  final batch = db.batch();

  final masters = ['Master_1', 'Master_2', 'Master_3'];
  for (final m in masters) {
    batch.insert('type_definitions', {
      'type_name': m,
      'display_name': m.replaceAll('_', ' '),
      'icon_name': 'insert_drive_file',
    });
  }

  final details = ['Detail_A', 'Detail_B', 'Detail_C'];
  for (final d in details) {
    batch.insert('type_definitions', {
      'type_name': d,
      'display_name': d.replaceAll('_', ' '),
      'icon_name': 'widgets',
    });
  }

  for (final m in masters) {
    for (final d in details) {
      batch.insert('type_relations', {
        'parent_type_name': m,
        'relation_name': 'contains',
        'child_type_name': d,
        'child_label': d.replaceAll('_', ' '),
      });
    }
  }

  final allTypes = [...masters, ...details];
  for (final t in allTypes) {
    for (int i = 1; i <= 3; i++) {
      batch.insert('type_attributes', {
        'type_name': t,
        'attr_key': 'field_$i',
        'label': 'Field $i',
        'attr_type': 'string',
        'section_label': 'General',
        'section_order': 0,
        'is_required': 0,
      });
    }
  }

  for (final m in masters) {
    batch.insert('properties', {
      'node_id': m,
      'data_json': jsonEncode({
        'field_1': 'val_${m}_field_1',
        'field_2': 'val_${m}_field_2',
        'field_3': 'val_${m}_field_3',
      }),
    });
  }

  for (final m in masters) {
    for (final d in details) {
      for (int k = 1; k <= 2; k++) {
        final instId = 'inst_${m}_${d}_$k';
        batch.insert('instances', {
          'id': instId,
          'parent_node_id': m,
          'type_name': d,
          'data_json': jsonEncode({
            'field_1': 'val_inst_${m}_${d}_${k}_field_1',
            'field_2': 'val_inst_${m}_${d}_${k}_field_2',
            'field_3': 'val_inst_${m}_${d}_${k}_field_3',
          }),
        });
      }
    }
  }

  await batch.commit(noResult: true);
  return db;
}

double _parseHudValue(String label, WidgetTester tester) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is Text && widget.data != null && widget.data!.startsWith(label),
  );
  if (finder.evaluate().isEmpty) {
    throw Exception('HUD label "$label" not found on screen');
  }
  final text = tester.widget<Text>(finder).data!;
  final parts = text.split(': ');
  if (parts.length < 2) {
    throw Exception('Could not parse "$label" value from HUD text: $text');
  }
  return double.parse(parts[1].split(' ')[0]);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Issue #50 — Camera resets on parent rebuild', () {
    testWidgets('Camera HUD values survive tree node tap (TreeViewModel notification)', (WidgetTester tester) async {
      const double width = 1280;
      const double height = 800;
      const double pixelRatio = 2.0;
      tester.view.physicalSize = const Size(width * pixelRatio, height * pixelRatio);
      tester.view.devicePixelRatio = pixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await StringResources.load();

      final db = await createTestDatabase();
      addTearDown(() async {
        await db.close();
      });

      final dataSource = SqliteDataSource(db);

      final themeController = ThemeController(SharedPreferencesThemeService());
      await themeController.loadSettings();

      final textScalerController = TextScalerController();
      await textScalerController.load();

      app_main.globalThemeController = themeController;
      app_main.globalTextScalerController = textScalerController;

      Future<void> settle(WidgetTester t) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await t.pump();
        for (int i = 0; i < 50; i++) {
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await t.pump();
        }
      }

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<DataSource>.value(value: dataSource),
            ChangeNotifierProvider<ThemeController>.value(value: themeController),
            ChangeNotifierProvider<TextScalerController>.value(value: textScalerController),
          ],
          child: const MyApp(),
        ),
      );

      await settle(tester);

      int attempts = 0;
      while (attempts < 20 && find.byKey(const Key('node_Master_1')).evaluate().isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
        attempts++;
      }

      expect(find.byKey(const Key('node_Master_1')), findsOneWidget,
          reason: 'Sidebar tree should contain Master_1');

      final toggle3dButton = find.byKey(const Key('toggle_3d'));
      if (toggle3dButton.evaluate().isNotEmpty) {
        await tester.ensureVisible(toggle3dButton);
        await tester.tap(toggle3dButton);
        await settle(tester);
      }

      expect(find.byType(Scene3DViewport), findsOneWidget,
          reason: '3D viewport should be mounted');

      await settle(tester);

      final initialLat = _parseHudValue('Latitude', tester);
      final initialLng = _parseHudValue('Longitude', tester);
      final initialAlt = _parseHudValue('Altitude', tester);

      expect(initialLat, isNotNull);
      expect(initialLng, isNotNull);
      expect(initialAlt, isNotNull);

      final master2Finder = find.byKey(const Key('node_Master_2'));
      await tester.ensureVisible(master2Finder);
      await tester.tap(master2Finder);
      await settle(tester);

      await settle(tester);

      final afterLat = _parseHudValue('Latitude', tester);
      final afterLng = _parseHudValue('Longitude', tester);
      final afterAlt = _parseHudValue('Altitude', tester);

      expect(afterLat, equals(initialLat),
          reason: 'Latitude should NOT change after tree node tap. '
              'Initial: $initialLat, After: $afterLat');
      expect(afterLng, equals(initialLng),
          reason: 'Longitude should NOT change after tree node tap. '
              'Initial: $initialLng, After: $afterLng');
      expect(afterAlt, equals(initialAlt),
          reason: 'Altitude should NOT change after tree node tap. '
              'Initial: $initialAlt, After: $afterAlt');
    });
  });
}
