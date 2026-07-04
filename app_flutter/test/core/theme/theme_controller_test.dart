import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_flutter/core/theme/theme_controller.dart';
import 'package:app_flutter/core/theme/theme_service.dart';

class FakeThemeService implements ThemeService {
  ThemeMode themeMode = ThemeMode.system;
  int themeScheme = 0;
  double textScale = 1.0;
  Axis? layoutSplitAxis;

  @override
  Future<ThemeMode> loadThemeMode() async => themeMode;

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    themeMode = mode;
  }

  @override
  Future<int> loadThemeScheme() async => themeScheme;

  @override
  Future<void> saveThemeScheme(int scheme) async {
    themeScheme = scheme;
  }

  @override
  Future<double> loadTextScale() async => textScale;

  @override
  Future<void> saveTextScale(double scale) async {
    textScale = scale;
  }

  @override
  Future<Axis> loadLayoutSplitAxis() async => layoutSplitAxis ?? Axis.vertical;

  @override
  Future<void> saveLayoutSplitAxis(Axis axis) async {
    layoutSplitAxis = axis;
  }
}

void main() {
  group('ThemeController - LayoutSplitAxis', () {
    late FakeThemeService fakeThemeService;
    late ThemeController controller;

    setUp(() {
      fakeThemeService = FakeThemeService();
      controller = ThemeController(fakeThemeService);
    });

    test('initial layoutSplitAxis should be Axis.vertical', () {
      expect(controller.layoutSplitAxis, Axis.vertical);
    });

    test('loadSettings loads saved layoutSplitAxis', () async {
      fakeThemeService.layoutSplitAxis = Axis.vertical;
      await controller.loadSettings();
      expect(controller.layoutSplitAxis, Axis.vertical);
    });

    test('updateLayoutSplitAxis updates layoutSplitAxis, calls notifyListeners, and saves to service', () async {
      bool notified = false;
      controller.addListener(() {
        notified = true;
      });

      await controller.updateLayoutSplitAxis(Axis.horizontal);

      expect(controller.layoutSplitAxis, Axis.horizontal);
      expect(notified, true);
      expect(fakeThemeService.layoutSplitAxis, Axis.horizontal);
    });

    test('updateLayoutSplitAxis with null or same value is a no-op', () async {
      bool notified = false;
      controller.addListener(() {
        notified = true;
      });

      await controller.updateLayoutSplitAxis(null);
      expect(notified, false);

      await controller.updateLayoutSplitAxis(Axis.vertical);
      expect(notified, false);
    });
  });

  group('SharedPreferencesThemeService - LayoutSplitAxis', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadLayoutSplitAxis returns Axis.vertical by default', () async {
      final service = SharedPreferencesThemeService();
      final axis = await service.loadLayoutSplitAxis();
      expect(axis, Axis.vertical);
    });

    test('saveLayoutSplitAxis persists the value and loadLayoutSplitAxis reads it', () async {
      final service = SharedPreferencesThemeService();
      await service.saveLayoutSplitAxis(Axis.vertical);

      final loaded = await service.loadLayoutSplitAxis();
      expect(loaded, Axis.vertical);
    });

    test('loadLayoutSplitAxis falls back to Axis.vertical if stored value is invalid', () async {
      SharedPreferences.setMockInitialValues({
        'layout_split_axis': 'invalid_value',
      });
      final service = SharedPreferencesThemeService();
      final loaded = await service.loadLayoutSplitAxis();
      expect(loaded, Axis.vertical);
    });
  });
}
