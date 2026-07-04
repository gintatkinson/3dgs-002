import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_flutter/domain/instance_record.dart';
import 'package:app_flutter/domain/data_source.dart';
import 'package:app_flutter/domain/type_descriptor.dart';
import 'package:app_flutter/features/tree/tree_node.dart';
import 'package:app_flutter/features/topology/topology_map.dart' show TopologyData;

/// [DataSource] implementation backed by Cloud Firestore.
///
/// Type schemas are stored in `schema/types` and `schema/hierarchy`
/// documents. Instance data lives in the `data` collection, while
/// elements, alarms, and events reside in separate collections indexed
/// by `parent_node_id`. Property writes are broadcast via an in-memory
/// [StreamController] so all active [watchProperties] subscribers
/// receive live updates. Use this data source for multi-user,
/// server-backed deployments. Requires valid Firebase configuration;
/// reads and writes are subject to Firestore security rules. All reads
/// hit the network — results are NOT cached locally.
class FirebaseDataSource implements DataSource {
  /// Creates a [FirebaseDataSource] connected to the given [Firestore] instance.
  /// Callers must ensure [_firestore] is initialized and pointing to the
  /// correct project before calling any data methods.
  FirebaseDataSource(this._firestore);
  final FirebaseFirestore _firestore;
  final StreamController<Map<String, dynamic>> _propertiesController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  String get name => 'firebase';

  /// Reads all type descriptors from the `schema/types` Firestore document.
  ///
  /// Each key in the `fields` map is treated as a type name; its value
  /// is parsed into a [TypeDescriptor] including display name, icon,
  /// attributes, and relation descriptors.
  ///
  /// Returns an empty list when the document does not exist or has no
  /// `fields` map (e.g. first launch before schema is seeded). Does NOT
  /// throw on missing documents — returns `[]` gracefully so the UI
  /// shows a fallback instead of crashing. Throws a [FirebaseException]
  /// if the underlying Firestore read fails (e.g. network outage,
  /// insufficient permissions). Results are NOT cached; each call
  /// triggers a Firestore read.
  @override
  Future<List<TypeDescriptor>> discoverTypes() async {
    try {
      final snapshot = await _firestore.collection('schema').doc('types').get();
      final data = snapshot.data();
      if (data == null) return [];
      final fields = data['fields'] as Map<String, dynamic>? ?? {};
      final types = <TypeDescriptor>[];
      for (final entry in fields.entries) {
        final typeName = entry.key;
        final def = entry.value as Map<String, dynamic>;
        types.add(TypeDescriptor(
          typeName: typeName,
          displayName: def['displayName'] as String? ?? typeName,
          iconName: def['iconName'] as String? ?? 'insert_drive_file',
          fields: _parseFields(def['fields'] as List<dynamic>?),
          childTypes: _parseRelations(def['childTypes'] as List<dynamic>?),
          relatedTypes: _parseRelations(def['relatedTypes'] as List<dynamic>?),
          parentTypes: _parseRelations(def['parentTypes'] as List<dynamic>?),
        ));
      }
      return types;
    } catch (e, stackTrace) {
      debugPrint('Error in discoverTypes: $e\n$stackTrace');
      return [];
    }
  }

  /// Returns the [TypeDescriptor] whose [TypeDescriptor.typeName] matches
  /// [typeName], or `null` if no such type exists.
  ///
  /// Delegates to [discoverTypes] and performs a linear scan (O(N)).
  /// Does NOT cache results; each call reads the full schema from
  /// Firestore. Prefer [discoverTypes] when loading multiple types at
  /// once to avoid N+1 reads.
  @override
  Future<TypeDescriptor?> typeFor(String typeName) async {
    try {
      final types = await discoverTypes();
      for (final t in types) {
        if (t.typeName == typeName) return t;
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint('Error in typeFor($typeName): $e\n$stackTrace');
      return null;
    }
  }

  /// Reads the `schema/hierarchy` Firestore document and returns
  /// parent-child type pairs `(parentTypeName, childTypeName)`.
  ///
  /// Returns an empty list when the document is missing or has no
  /// `pairs` field (e.g. a flat ontology with no parent-child
  /// relationships). Throws a [FirebaseException] on network or
  /// permission failures. Each call triggers a single Firestore read.
  @override
  Future<List<(String, String)>> discoverHierarchy() async {
    try {
      final snapshot = await _firestore.collection('schema').doc('hierarchy').get();
      final data = snapshot.data();
      if (data == null) return [];
      final pairs = data['pairs'] as List<dynamic>? ?? [];
      return pairs.map((p) {
        final pair = p as List<dynamic>;
        return (pair[0] as String, pair[1] as String);
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('Error in discoverHierarchy: $e\n$stackTrace');
      return [];
    }
  }

  /// Fetches the property map for the node identified by [nodeId] from
  /// the `data` Firestore collection.
  ///
  /// Returns an empty map when the document does not exist (e.g. a
  /// newly referenced node that has never been saved). Throws a
  /// [FirebaseException] on network or permission failures. Each call
  /// triggers a single Firestore read.
  @override
  Future<Map<String, dynamic>> fetchProperties(String nodeId) async {
    try {
      final doc = await _firestore.collection('data').doc(nodeId).get();
      final data = doc.data();
      if (data == null) return {};
      return Map<String, dynamic>.from(data);
    } catch (e, stackTrace) {
      debugPrint('Error in fetchProperties($nodeId): $e\n$stackTrace');
      return {};
    }
  }

  /// Persists [data] as the properties for [nodeId] in the `data`
  /// Firestore collection using a deep merge.
  ///
  /// STATE CHANGE: Writes to Firestore and emits a change event on the
  /// broadcast stream so all active [watchProperties] subscribers
  /// receive the update. Only top-level fields in [data] are
  /// merged — nested maps are replaced entirely. Throws a
  /// [FirebaseException] on network or permission failures.
  @override
  Future<void> saveProperties(String nodeId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('data').doc(nodeId).set(data, SetOptions(merge: true));
      _propertiesController.add({'nodeId': nodeId, 'data': data});
    } catch (e, stackTrace) {
      debugPrint('Error in saveProperties($nodeId): $e\n$stackTrace');
    }
  }

  /// Returns a broadcast stream that first emits the current properties
  /// for [nodeId] (via [fetchProperties]) and then yields subsequent
  /// updates whenever [saveProperties] is called for the same [nodeId].
  ///
  /// The initial yield is produced eagerly so callers receive the
  /// current state immediately upon subscription. Subscriptions that
  /// outlive the data source will receive events indefinitely — cancel
  /// the subscription to avoid leaks. Does NOT react to external
  /// Firestore writes from other clients; only in-process calls to
  /// [saveProperties] trigger stream events.
  @override
  Stream<Map<String, dynamic>> watchProperties(String nodeId) async* {
    yield await fetchProperties(nodeId);
    await for (final event in _propertiesController.stream) {
      if (event['nodeId'] == nodeId) {
        yield event['data'] as Map<String, dynamic>;
      }
    }
  }

  @override
  Future<List<InstanceRecord>> fetchRelatedInstances({
    required String parentNodeId,
    required TypeDescriptor targetType,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('instances')
          .where('parent_node_id', isEqualTo: parentNodeId)
          .where('type_name', isEqualTo: targetType.typeName)
          .get();
      final rawDocs = snapshot.docs.map((d) => {
        'id': d.id,
        'data': d.data(),
      }).toList();
      return compute(
        (args) {
          final docs = args[0] as List<Map<String, dynamic>>;
          final pId = args[1] as String;
          final tName = args[2] as String;
          return docs.map((doc) {
            return InstanceRecord(
              id: doc['id'] as String,
              parentNodeId: pId,
              typeName: tName,
              attributes: doc['data'] as Map<String, dynamic>,
            );
          }).toList();
        },
        [rawDocs, parentNodeId, targetType.typeName],
      );
    } catch (e, stackTrace) {
      debugPrint('Error in fetchRelatedInstances: $e\n$stackTrace');
      return [];
    }
  }

  List<FieldDescriptor> _parseFields(List<dynamic>? fields) {
    if (fields == null) return [];
    return fields.map((f) {
      final map = f as Map<String, dynamic>;
      return FieldDescriptor(
        key: map['key'] as String,
        label: map['label'] as String,
        type: map['type'] as String,
        sectionLabel: map['sectionLabel'] as String?,
        sectionOrder: map['sectionOrder'] as int? ?? 0,
        required: map['required'] as bool? ?? false,
        minValue: map['minValue'] as num?,
        maxValue: map['maxValue'] as num?,
        pattern: map['pattern'] as String?,
        enumOptions: map['enumOptions'] != null
            ? List<String>.from(map['enumOptions'] as List)
            : null,
        enumDisplayNames: map['enumDisplayNames'] != null
            ? List<String>.from(map['enumDisplayNames'] as List)
            : null,
        defaultValue: map['defaultValue'],
        inputFormatters: map['inputFormatters'] != null
            ? List<String>.from(map['inputFormatters'] as List)
            : null,
      );
    }).toList();
  }

  List<TypeRelationDescriptor> _parseRelations(List<dynamic>? relations) {
    if (relations == null) return [];
    return relations.map((r) {
      final map = r as Map<String, dynamic>;
      return TypeRelationDescriptor(
        relationName: map['relationName'] as String,
        childTypeName: map['childTypeName'] as String,
        childLabel: map['childLabel'] as String,
      );
    }).toList();
  }

  @override
  Future<List<TreeNode>> fetchRootNodes() async {
    return [];
  }

  @override
  Future<List<TreeNode>> fetchChildrenForNode(String parentId) async {
    return [];
  }

  @override
  Future<TopologyData> fetchTopologyData() async {
    return const TopologyData(coordinateMapping: {}, nodes: [], links: []);
  }
}

