# Code Review: Database, Schema, Data Sources, and Domain Layers

This document contains a thorough code review of the Flutter codebase's persistence and domain layers, evaluated across eight core categories.

---

## 1. Context Understanding

### 🔴 Critical: Firebase Data Source Tree/Topology Unimplemented Stubs
- **Severity**: 🔴 Critical
- **Location**: [firebase_data_source.dart:L255-L267](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/data_sources/firebase_data_source.dart#L255-L267)
- **Issue**: The methods `fetchRootNodes()`, `fetchChildrenForNode()`, and `fetchTopologyData()` are defined in the `DataSource` interface, but are left as stub/empty implementations in `FirebaseDataSource`. If the app switches to the Firebase backend, the navigation sidebar, master-detail tree, and topology map will be completely empty and broken.
- **Suggestion**: Implement the tree traversal and topology nodes mapping for Cloud Firestore by querying the `data` and/or relations collections, matching the functionality of `SqliteDataSource`.
- **Example**:
  ```dart
  @override
  Future<List<TreeNode>> fetchRootNodes() async {
    try {
      final snapshot = await _firestore
          .collection('data')
          .where('parent_node_id', isNull: true) // Assuming parent_node_id represents hierarchy in Firestore
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return TreeNode(
          id: doc.id,
          label: data['name']?.toString() ?? doc.id,
          children: const [], // Load children dynamically
        );
      }).toList();
    } catch (e) {
      debugPrint('Error in fetchRootNodes: $e');
      return [];
    }
  }
  ```

---

## 2. Correctness Analysis

### 🔴 Critical: Outdated Database Check Bug (Constant Database Recreation)
- **Severity**: 🔴 Critical
- **Location**: [repository_resolver.dart:L132](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/repository_resolver.dart#L132)
- **Issue**: The detection of an outdated local database relies on querying `SELECT COUNT(*) as count FROM type_attributes WHERE attr_key = 'raw_json'`. However, no type attribute in the seed or production data has `attr_key = 'raw_json'`. Therefore, this query always returns `0`, causing `isOutdated` to be `true` on *every single startup*. The database file is deleted and re-seeded from assets on every app launch, causing total silent data loss for any local changes.
- **Suggestion**: Change this check to detect structural table existence, a DB schema version metadata table, or remove it in favor of a standard SQLite version migration path.
- **Example**:
  ```dart
  // Check if a standard table (e.g., properties) exists instead
  final rows = await tempDb.rawQuery(
    "SELECT COUNT(*) as count FROM sqlite_master WHERE type='table' AND name='properties'"
  );
  final count = rows.first['count'] as int? ?? 0;
  if (count == 0) {
    isOutdated = true;
  }
  ```

### 🔴 Critical: Orphaning Child Nodes on Save Properties (Data Loss)
- **Severity**: 🔴 Critical
- **Location**: [sqlite_data_source.dart:L168-L172](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/data_sources/sqlite_data_source.dart#L168-L172)
- **Issue**: `saveProperties` calls `_db.insert` with `ConflictAlgorithm.replace` using a map containing only `node_id` and `data_json`. Because `parent_node_id` is omitted from this map, it will be set to `NULL` in the replaced row. Consequently, saving properties for any nested child node silently orphans it from its parent, detaching it from the tree.
- **Suggestion**: Use SQL `ON CONFLICT` UPSERT syntax that only updates the `data_json` column and leaves the existing `parent_node_id` untouched.
- **Example**:
  ```dart
  await _db.execute('''
    INSERT INTO properties (node_id, data_json)
    VALUES (?, ?)
    ON CONFLICT(node_id) DO UPDATE SET
      data_json = excluded.data_json
  ''', [nodeId, dataJson]);
  ```

### 🟠 Important: Flat Map Pollution in `InstanceRecord.fromMap`
- **Severity**: 🟠 Important
- **Location**: [instance_record.dart:L40-L50](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/instance_record.dart#L40-L50)
- **Issue**: When `map['data_json']` is null, `attrs` is set to `Map<String, dynamic>.from(map)`. This pollutes the domain attributes with metadata columns like `id`, `parent_node_id`, and `type_name`. Conversely, if `data_json` is present, `attributes` only contains domain fields. This inconsistency leads to unpredictable behaviors during schema validation and UI form rendering.
- **Suggestion**: Ensure that flat database columns are explicitly removed from `attrs` when falling back to the map.
- **Example**:
  ```dart
  } else {
    attrs = Map<String, dynamic>.from(map)
      ..remove('id')
      ..remove('parent_node_id')
      ..remove('type_name')
      ..remove('data_json');
  }
  ```

---

## 3. Security Review

### 🟠 Important: Missing Relational Constraints on `instances` Table
- **Severity**: 🟠 Important
- **Location**: [database_initializer.dart:L83-L89](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/database_initializer.dart#L83-L89)
- **Issue**: Unlike `properties`, `type_attributes`, and `type_relations`, the `instances` table definition does not enforce foreign keys on `parent_node_id` and `type_name`. This allows the insertion of instances that point to non-existent nodes or invalid types, causing database drift and potential application crashes due to broken references.
- **Suggestion**: Add foreign key constraints to the `instances` table schema.
- **Example**:
  ```sql
  CREATE TABLE IF NOT EXISTS instances (
    id TEXT PRIMARY KEY,
    parent_node_id TEXT NOT NULL REFERENCES properties(node_id) ON DELETE CASCADE,
    type_name TEXT NOT NULL REFERENCES type_definitions(type_name) ON DELETE CASCADE,
    data_json TEXT NOT NULL
  )
  ```

### 🟠 Important: Lack of Input Type Verification in Validation Layer
- **Severity**: 🟠 Important
- **Location**: [validation.dart:L4, L21, L40-L42](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/validation.dart#L4)
- **Issue**: Validation functions cast map values directly (e.g., `as String?`, `as num?`). If the payload contains mismatched JSON types (such as an integer for `countryCode` or a boolean for `maxVoltage`), these functions will throw a runtime `TypeError` and crash the application, rather than returning a validation failure state.
- **Suggestion**: Use safer checks or try-parse wrappers to sanitize incoming types before casting.
- **Example**:
  ```dart
  bool validatePostalAddress(Map<String, dynamic> addr) {
    final countryCode = addr['countryCode']?.toString() ?? '';
    if (countryCode.isEmpty) {
      return false;
    }
    final countryRegex = RegExp(r'^[A-Z]{2}$');
    return countryRegex.hasMatch(countryCode);
  }
  ```

---

## 4. Performance Considerations

### 🔴 Critical: Missing Database Indexes on `instances` Table
- **Severity**: 🔴 Critical
- **Location**: [database_initializer.dart:L83-L89](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/database_initializer.dart#L83-L89)
- **Issue**: The `instances` table is queried by `parent_node_id` and `type_name` in both `SqliteDataSource.fetchRelatedInstances` and `SqliteDataSource.fetchChildrenForNode`. Under a standard seed load containing up to 240,000 instances, SQLite is forced to run a full table scan on every lookup, locking the UI thread and freezing the application.
- **Suggestion**: Add a composite index on `instances(parent_node_id, type_name)`.
- **Example**:
  ```sql
  CREATE INDEX IF NOT EXISTS idx_instances_parent_type
  ON instances(parent_node_id, type_name);
  ```

### 🟠 Important: UI Thread Blocking in `SqliteDataSource.fetchTopologyData`
- **Severity**: 🟠 Important
- **Location**: [sqlite_data_source.dart:L373-L462](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/data_sources/sqlite_data_source.dart#L373-L462)
- **Issue**: `fetchTopologyData` retrieves all `properties` rows and decodes their JSON string maps (up to 16,000+ entries) on the main UI thread. Running nested JSON decodes and regex matching sequentially on the main thread will cause severe frame drops and freezes when opening the topology view.
- **Suggestion**: Move the JSON decoding and coordinate transformation logic to a background isolate using Flutter's `compute` function.
- **Example**:
  ```dart
  @override
  Future<TopologyData> fetchTopologyData() async {
    try {
      final rows = await _db.query('properties');
      final interfaceRows = await _db.query('instances', where: "type_name = 'interface'");
      
      return await compute(_parseTopologyOnIsolate, [rows, interfaceRows]);
    } catch (e) {
      return const TopologyData(coordinateMapping: {}, nodes: [], links: []);
    }
  }
  ```

### 🟠 Important: N+1 Network Reads in `FirebaseDataSource.typeFor`
- **Severity**: 🟠 Important
- **Location**: [firebase_data_source.dart:L82-L93](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/data_sources/firebase_data_source.dart#L82-L93)
- **Issue**: `typeFor` calls `discoverTypes()` every time it is called. Since `discoverTypes()` reads the `schema/types` document directly from Firestore with no local caching, retrieving multiple types in quick succession creates N+1 Firestore reads, which increases response latency and Google Cloud API costs.
- **Suggestion**: Introduce a simple in-memory cache for `TypeDescriptor` lists in `FirebaseDataSource`.
- **Example**:
  ```dart
  List<TypeDescriptor>? _cachedTypes;

  @override
  Future<List<TypeDescriptor>> discoverTypes() async {
    if (_cachedTypes != null) return _cachedTypes!;
    // Perform Firestore fetch...
    _cachedTypes = types;
    return types;
  }
  ```

---

## 5. Code Quality & Readability

### 🟡 Suggestion: Unregistered `'widgets'` Icon in `IconMapper`
- **Severity**: 🟡 Suggestion
- **Location**: [icon_mapper.dart:L15-L32](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/icon_mapper.dart#L15-L32) & [database_initializer.dart:L150](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/database_initializer.dart#L150)
- **Issue**: During seeding, detail nodes (`Detail_A`, `Detail_B`, `Detail_C`) are assigned `icon_name: 'widgets'`. However, `'widgets'` is missing from `IconMapper._icons`. As a result, detail nodes fall back to showing `Icons.insert_drive_file` instead of the expected widget icon.
- **Suggestion**: Register `'widgets'` in `IconMapper._icons`.
- **Example**:
  ```dart
  static const Map<String, IconData> _icons = {
    ...
    'insert_drive_file': Icons.insert_drive_file,
    'widgets': Icons.widgets,
    ...
  };
  ```

### 🟡 Suggestion: Swallowing IO / Copy Errors in `RepositoryResolver`
- **Severity**: 🟡 Suggestion
- **Location**: [repository_resolver.dart:L154-L165](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/repository_resolver.dart#L154-L165)
- **Issue**: Empty `catch (_)` blocks are used during database asset copying. If copy operations fail because the asset is missing, renamed, or corrupted, the system fails silently and attempts to open an uninitialized file, leading to obscure downstream crashes that are hard to diagnose.
- **Suggestion**: Log exceptions or rethrow them to simplify troubleshooting.
- **Example**:
  ```dart
  } catch (e, stack) {
    debugPrint('Failed to load or decode database asset: $e\n$stack');
    rethrow;
  }
  ```

---

## 6. Architecture & Design

### 🔴 Critical: Liskov Substitution Principle Violation in `FirebaseDataSource`
- **Severity**: 🔴 Critical
- **Location**: [firebase_data_source.dart:L255-L267](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/data_sources/firebase_data_source.dart#L255-L267)
- **Issue**: Returning empty stubs for `fetchRootNodes()`, `fetchChildrenForNode()`, and `fetchTopologyData()` violates the contract of the `DataSource` interface. The `FirebaseDataSource` subclass cannot be substituted for `SqliteDataSource` without causing critical UI failures.
- **Suggestion**: Fully implement these methods using Firestore queries, or throw an explicit `UnimplementedError` so developers are immediately alerted to the architectural gap.

### 🟠 Important: Missing Real-Time Updates in `FirebaseDataSource`
- **Severity**: 🟠 Important
- **Location**: [firebase_data_source.dart:L168-L175](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/data_sources/firebase_data_source.dart#L168-L175)
- **Issue**: `watchProperties` listens to a local `StreamController` that only fires when properties are saved *in-process*. It does not listen to Firestore `snapshots()`. This prevents the application from receiving real-time updates from other clients/servers, defeating a primary value proposition of using Cloud Firestore.
- **Suggestion**: Bind the returned stream directly to Firestore's snapshot stream.
- **Example**:
  ```dart
  @override
  Stream<Map<String, dynamic>> watchProperties(String nodeId) {
    return _firestore.collection('data').doc(nodeId).snapshots().map((snapshot) {
      return snapshot.data() ?? {};
    });
  }
  ```

---

## 7. Testing

### 💡 Nitpick: Unused BDD / Validation Factory in Production Code
- **Severity**: 💡 Nitpick
- **Location**: [instance_record.dart:L62-L70](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/instance_record.dart#L62-L70)
- **Issue**: `InstanceRecord.fromMapWithValidation` is defined but only called inside tests (`instance_record_test.dart`). It increases codebase footprint and testing/maintenance overhead without being used in production.
- **Suggestion**: Remove this factory and perform validation explicitly in code, or integrate it directly into data sources during ingestion.

---

## 8. Documentation

### 💡 Nitpick: Outdated Comment on `discoverTypes` Query Complexity
- **Severity**: 💡 Nitpick
- **Location**: [sqlite_data_source.dart:L30-L38](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/data_sources/sqlite_data_source.dart#L30-L38)
- **Issue**: The docstring claims that `discoverTypes` executes `1 + N` SQL queries (where N is the type count). The implementation was previously optimized to execute only 3 queries in bulk, meaning this documentation has drifted and is misleading.
- **Suggestion**: Update the docstring to correctly state that type definitions, attributes, and relations are queried in bulk.
