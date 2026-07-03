# API Reference

> Public interfaces and classes for extending the platform.

## Core Abstractions

### DataSource

**File:** `lib/domain/data_source.dart`

The swappable backend interface. Implementations:
- `SqliteDataSource` — local SQLite database
- `FirebaseDataSource` — Firebase Firestore
- `GrpcDataSource` — gRPC-based backend

**Methods:**

| Method | Returns | Description |
|--------|---------|-------------|
| `discoverTypes()` | `Future<List<TypeDescriptor>>` | All object types known to this backend |
| `typeFor(String)` | `Future<TypeDescriptor?>` | Get a specific type by name |
| `discoverHierarchy()` | `Future<List<(String, String)>>` | Parent-child relationships |
| `fetchProperties(String)` | `Future<Map<String, dynamic>>` | Get properties for a node |
| `saveProperties(String, Map)` | `Future<void>` | Save properties for a node |
| `watchProperties(String)` | `Stream<Map<String, dynamic>>` | Reactive property updates |
| `fetchElements(String)` | `Future<List<Map<String, dynamic>>>` | Child elements of a node |
| `fetchAlarms(String)` | `Future<List<Map<String, dynamic>>>` | Alarms associated with a node |
| `fetchEvents(String)` | `Future<List<Map<String, dynamic>>>` | Events associated with a node |

### TypeDescriptor

**File:** `lib/domain/type_descriptor.dart`

Describes one object type. Contains:
- `typeName`, `displayName`, `iconName` — identity
- `fields` — list of `FieldDescriptor`
- `childTypes` — hierarchy children (tree)
- `relatedTypes` — associated data (tabs)
- `parentTypes` — reverse hierarchy

### FieldDescriptor

Describes one field of a type. Contains:
- `key`, `label`, `type` — identity
- `sectionLabel`, `sectionOrder` — UI grouping
- `minValue`, `maxValue`, `pattern`, `required` — validation
- `enumOptions`, `defaultValue`, `inputFormatters` — input behavior

### TypeRelationDescriptor

Describes a relationship between two types. Contains:
- `relationName` — semantic name (e.g. "contains", "belongs_to")
- `childTypeName` — the related type's name
- `childLabel` — human-readable plural label for UI tabs

## Widgets

### PropertyGrid

**File:** `lib/features/properties/property_grid.dart`

A form-like widget that renders editable fields for a selected node. Reads fields from `FieldDescriptor` list; emits changes via `onSave` callback. Supports per-section grouping, validation, and custom input formatters.

### SidebarTree

**File:** `lib/features/tree/sidebar_tree.dart`

The navigation tree in the left sidebar. Reads tree data from `TreeViewModel` via `context.watch`. Emits view selection changes via `onViewSelected` callback.

### TabbedContainer

**File:** `lib/features/tables/tabbed_container.dart`

A tabbed detail pane that renders associated data (elements, alarms, events) in table views. Reads tab labels from `TablesViewModel` via `context.watch`.
