# Domain Deployment Guide

> How to take this generic Flutter platform and configure it for your specific domain (e.g., a library's book catalog, a hospital's patient records, a warehouse's inventory).

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Prerequisites](#2-prerequisites)
3. [Step 1: Define Your Ontology](#3-step-1-define-your-ontology)
4. [Step 2: Seed the Database](#4-step-2-seed-the-database)
5. [Step 3: Regenerate the Pre-built Database](#5-step-3-regenerate-the-pre-built-database)
6. [Step 4: (Optional) Customize the Layout](#6-step-4-optional-customize-the-layout)
7. [Step 5: Rebuild and Test](#7-step-5-rebuild-and-test)
8. [Step 6: (Advanced) Wire a Different Data Source](#8-step-6-advanced-wire-a-different-data-source)
9. [Example: Library Domain](#9-example-library-domain)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Architecture Overview

The platform discovers your domain schema at runtime — no code changes needed. Here is the data flow:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         SQLite DB (assets/properties_db.db)         │
│  ┌─────────────────┐  ┌──────────────────┐  ┌───────────────────┐  │
│  │ type_definitions │  │ type_attributes  │  │ type_relations    │  │
│  │ (type_name,      │  │ (attr_key, label, │  │ (parent_type,     │  │
│  │  display_name,   │  │  attr_type, ...)  │  │  child_type, ...) │  │
│  │  icon_name)      │  │                   │  │                   │  │
│  └────────┬─────────┘  └────────┬──────────┘  └────────┬──────────┘  │
│           │                     │                       │             │
└───────────┼─────────────────────┼───────────────────────┼─────────────┘
            │                     │                       │
            ▼                     ▼                       ▼
┌──────────────────────────────────────────────────────────────────────┐
│  SqliteDataSource (implements DataSource)                            │
│  - discoverTypes() → reads type_definitions + type_attributes        │
│  - discoverHierarchy() → reads type_relations                        │
│  - typeFor(name) → single-type lookup                                │
└──────────────────────────┬───────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│  TypeDescriptor (one per object type, e.g. "Book", "Author")        │
│  - typeName, displayName, iconName                                  │
│  - fields: List<FieldDescriptor>                                    │
│  - childTypes / parentTypes: List<TypeRelationDescriptor>            │
└──────────────────────────┬───────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│  TreeViewModel (consumes TypeDescriptors via DataSource)            │
│  - loadTree() → calls discoverTypes() + discoverHierarchy()          │
│  - builds TreeNode hierarchy → populates sidebar                     │
└──────────────────────────┬───────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│  Widgets (PropertyGrid, sidebar tree, topology map, tab tables)     │
│  - Rendered from logical-layout.json structure                       │
│  - Property fields derived from FieldDescriptors                     │
└──────────────────────────────────────────────────────────────────────┘
```

**Key insight:** The app has zero hardcoded domain knowledge. Everything — the sidebar tree, the property forms, the table columns — is driven by what your `DataSource` returns. Add rows to the database tables and the UI adapts immediately.

---

## 2. Prerequisites

- **Flutter SDK** 3.12+ (stable channel)
- **Clone** of this repository
- **Dependencies installed:**

```bash
cd app_flutter
flutter pub get
```

- **Python 3** (only needed if you use the SQL seed script helper)
- **SQLite CLI** (optional, for manual inspection):

```bash
sqlite3 assets/properties_db.db ".tables"
```

---

## 3. Step 1: Define Your Ontology

You describe your domain using three database tables. Think of this as writing a schema for your world.

### 3.1 Type Definitions

Each real-world object type gets one row in `type_definitions`.

| Column       | Purpose                                                  | Example (Library)   |
|--------------|----------------------------------------------------------|---------------------|
| `type_name`  | Internal ID used everywhere in the app                   | `Book`              |
| `display_name` | Label shown in the sidebar and UI headers              | `Book`              |
| `icon_name`  | Material Design icon name (see [Material Icons](https://fonts.google.com/icons)) | `menu_book`         |

**Rules:**
- `type_name` must be unique — use `PascalCase`.
- `icon_name` is the snake_case name from the Material icon set (e.g., `person`, `category`, `dns`). Defaults to `insert_drive_file` if omitted.

### 3.2 Type Attributes (Fields)

Each field of an object type gets one row in `type_attributes`.

| Column               | Purpose                                                         | Example                       |
|----------------------|-----------------------------------------------------------------|-------------------------------|
| `attr_key`           | Unique key within the type, used as the JSON property key       | `title`                       |
| `label`              | Label displayed in the property form                            | `Title`                       |
| `attr_type`          | Data type: `string`, `int`, `double`, `enum`, `date`            | `string`                      |
| `section_label`      | Groups fields in the UI form (null = "Other" section)           | `Details`                     |
| `section_order`      | Order within the section (lower = first)                        | `0`                           |
| `is_required`        | `1` = required, `0` = optional                                  | `1`                           |
| `min_value`          | Minimum numeric value (int/double only)                         | `1`                           |
| `max_value`          | Maximum numeric value (int/double only)                         | `10000`                       |
| `pattern`            | Regex validation pattern (string only)                          | `^[A-Z]+$`                    |
| `enum_options`       | JSON array of allowed values (enum only)                        | `["Fiction","Non-Fiction"]`   |
| `enum_display_names` | JSON array of display labels matching `enum_options`            | `["Fiction","Non-Fiction"]`   |
| `default_value`      | Default when creating a new instance                            | `Unknown`                     |
| `input_formatters`   | JSON array of formatter names, e.g. `["uppercase"]`             | `["uppercase"]`               |

**Rules:**
- `attr_key` must be unique _within_ a type (the table has a `UNIQUE(type_name, attr_key)` constraint).
- `enum_options` and `enum_display_names` are stored as JSON text strings (e.g., `'["Fiction","Non-Fiction"]'`).
- `is_required` is stored as `0` (false) or `1` (true).
- `section_order` starts at `0`.

### 3.3 Type Relations (Hierarchy)

Parent-child relationships define the sidebar tree and tab-table lookups.

| Column              | Purpose                                            | Example              |
|---------------------|----------------------------------------------------|----------------------|
| `parent_type_name`  | The parent type in the hierarchy                   | `Genre`              |
| `relation_name`     | Semantic name of the relationship                  | `contains`           |
| `child_type_name`   | The child type in the hierarchy                    | `Book`               |
| `child_label`       | Plural label shown in the child tab table           | `Books`              |

**Rules:**
- A type can appear as both parent and child, forming a tree.
- The `TreeViewModel` builds the sidebar tree by placing each type under its parent. Types without a parent appear as top-level nodes in the sidebar.
- `child_label` is used as the tab header in the UI (e.g., "Books" tab under a Genre).

### 3.4 Ontology Worksheet

Before writing SQL, sketch your domain on paper. For a library:

```
Object types:      Genre, Book, Author, Patron, Loan
Root types:        Genre (top-level)
Hierarchy:         Genre → contains → Book
                   Book  → written_by → Author
                   Book  → lent_to → Patron (via Loan?)

Fields of Book:    title (string, required), pages (int, 1-10000),
                   ISBN (string, pattern: ^\\d{13}$), genre (enum)
```

---

## 4. Step 2: Seed the Database

You have two options: write raw SQL and pipe it into the database, or create a Dart seed script.

### Option A: SQL Seed Script (Recommended)

Create a file like `scripts/seed_library.sql`:

```sql
-- ============================================================
-- Library Domain Seed
-- ============================================================

-- 4.1 Type Definitions
INSERT INTO type_definitions VALUES ('Genre', 'Genre', 'category');
INSERT INTO type_definitions VALUES ('Book', 'Book', 'menu_book');
INSERT INTO type_definitions VALUES ('Author', 'Author', 'person');
INSERT INTO type_definitions VALUES ('Patron', 'Patron', 'people');
INSERT INTO type_definitions VALUES ('Loan', 'Loan', 'receipt_long');

-- 4.2 Type Relations (hierarchy)
INSERT INTO type_relations VALUES (1, 'Genre', 'contains', 'Book', 'Books');
INSERT INTO type_relations VALUES (2, 'Book', 'written_by', 'Author', 'Authors');
INSERT INTO type_relations VALUES (3, 'Book', 'borrowed_by', 'Patron', 'Borrowers');
INSERT INTO type_relations VALUES (4, 'Patron', 'has_loan', 'Loan', 'Loans');

-- 4.3 Type Attributes — Genre
INSERT INTO type_attributes
  (type_name, attr_key, label, attr_type, section_label, section_order, is_required)
VALUES
  ('Genre', 'name', 'Name', 'string', 'Details', 0, 1),
  ('Genre', 'description', 'Description', 'string', 'Details', 1, 0);

-- 4.4 Type Attributes — Book
INSERT INTO type_attributes
  (type_name, attr_key, label, attr_type, section_label, section_order, is_required, min_value, max_value)
VALUES
  ('Book', 'title', 'Title', 'string', 'Details', 0, 1, NULL, NULL),
  ('Book', 'subtitle', 'Subtitle', 'string', 'Details', 1, 0, NULL, NULL),
  ('Book', 'pages', 'Page Count', 'int', 'Details', 2, 0, 1, 10000),
  ('Book', 'isbn', 'ISBN-13', 'string', 'Identifiers', 0, 0, NULL, NULL),
  ('Book', 'publish_year', 'Publish Year', 'int', 'Details', 3, 0, 1400, 2030);

-- Enum attribute example
INSERT INTO type_attributes
  (type_name, attr_key, label, attr_type, section_label, section_order, is_required,
   min_value, max_value, pattern, enum_options, enum_display_names, default_value, input_formatters)
VALUES
  ('Book', 'genre_type', 'Genre Type', 'enum', 'Classification', 0, 0,
   NULL, NULL, NULL,
   '["Fiction","Non-Fiction","Reference","Periodical"]',
   '["Fiction","Non-Fiction","Reference","Periodical"]',
   'Fiction', NULL);

-- 4.5 Type Attributes — Author
INSERT INTO type_attributes
  (type_name, attr_key, label, attr_type, section_label, section_order, is_required)
VALUES
  ('Author', 'name', 'Full Name', 'string', 'Details', 0, 1),
  ('Author', 'birth_year', 'Birth Year', 'int', 'Details', 1, 0),
  ('Author', 'nationality', 'Nationality', 'string', 'Details', 2, 0);

-- 4.6 Type Attributes — Patron
INSERT INTO type_attributes
  (type_name, attr_key, label, attr_type, section_label, section_order, is_required)
VALUES
  ('Patron', 'name', 'Name', 'string', 'Details', 0, 1),
  ('Patron', 'email', 'Email', 'string', 'Details', 1, 0),
  ('Patron', 'phone', 'Phone', 'string', 'Details', 2, 0),
  ('Patron', 'member_since', 'Member Since', 'date', 'Details', 3, 0);

-- 4.7 Type Attributes — Loan
INSERT INTO type_attributes
  (type_name, attr_key, label, attr_type, section_label, section_order, is_required)
VALUES
  ('Loan', 'checkout_date', 'Checkout Date', 'date', 'Details', 0, 1),
  ('Loan', 'due_date', 'Due Date', 'date', 'Details', 1, 1),
  ('Loan', 'returned', 'Returned', 'enum', 'Details', 2, 1),
  ('Loan', 'notes', 'Notes', 'string', 'Details', 3, 0);
```

Then apply it:

```bash
cd app_flutter
# Delete the old database first
rm -f assets/properties_db.db
# Create a fresh one with schema only
dart run scripts/generate_db.dart
# Seed it with your ontology
sqlite3 assets/properties_db.db < scripts/seed_library.sql
# Verify
sqlite3 assets/properties_db.db "SELECT type_name, display_name FROM type_definitions;"
```

### Option B: Dart Seed Script (For Complex Logic)

Create `scripts/seed_library.dart`:

```dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = p.join(Directory.current.path, 'assets', 'properties_db.db');
  final db = await databaseFactory.openDatabase(dbPath);

  await db.transaction((txn) async {
    // Type definitions
    await txn.execute("INSERT INTO type_definitions VALUES ('Genre', 'Genre', 'category')");
    await txn.execute("INSERT INTO type_definitions VALUES ('Book', 'Book', 'menu_book')");
    await txn.execute("INSERT INTO type_definitions VALUES ('Author', 'Author', 'person')");

    // Relations
    await txn.execute("INSERT INTO type_relations VALUES (1, 'Genre', 'contains', 'Book', 'Books')");
    await txn.execute("INSERT INTO type_relations VALUES (2, 'Book', 'written_by', 'Author', 'Authors')");

    // Attributes
    await txn.execute('''
      INSERT INTO type_attributes
        (type_name, attr_key, label, attr_type, section_label, section_order, is_required)
      VALUES ('Book', 'title', 'Title', 'string', 'Details', 0, 1)
    ''');
    await txn.execute('''
      INSERT INTO type_attributes
        (type_name, attr_key, label, attr_type, section_label, section_order, is_required)
      VALUES ('Book', 'subtitle', 'Subtitle', 'string', 'Details', 1, 0)
    ''');
  });

  await db.close();
  print('Library domain seeded successfully.');
}
```

Run it:

```bash
cd app_flutter && dart run scripts/seed_library.dart
```

---

## 5. Step 3: Regenerate the Pre-built Database

The app bundles the database as an asset. After seeding, regenerate it:

```bash
cd app_flutter && dart run scripts/generate_db.dart
```

This script:
1. Deletes the old `assets/properties_db.db` if it exists.
2. Creates a fresh SQLite database at `assets/properties_db.db`.
3. Creates all required tables: `properties`, `elements`, `alarms`, `events`, `type_definitions`, `type_attributes`, `type_relations`.

The script only creates the schema — it does NOT insert seed data. After running it, you must seed your ontology. The two steps can be combined in a single script if preferred.

**Important:** The `generate_db.dart` script creates an _empty_ database with just the schema. If you run it after seeding, you will lose your seed data. The correct order is:

```bash
dart run scripts/generate_db.dart    # 1. Create schema
sqlite3 assets/properties_db.db < scripts/seed_library.sql  # 2. Seed
```

Or roll both into a single script (option B above).

---

## 6. Step 4: (Optional) Customize the Layout

The file `assets/logical-layout.json` controls the application layout — the sidebar, the pane split ratios, the tabs shown in the detail panel, and the topology map settings.

### What you can change

- **Sidebar hierarchy** (`layout.root_container.children[0].props.hierarchy`): The static navigation tree. This is the fallback structure shown before the `DataSource` loads. The runtime tree from `TreeViewModel` (driven by `discoverTypes`/`discoverHierarchy`) takes over once loaded.
- **Tab labels** (`props.label` on `TableView` widgets): Change the text of the "Items", "Status", "Activity" tabs.
- **Pane dimensions** (`props.default_ratio`): Adjust the horizontal split between topology and tab tables.
- **Theme colors** (`theme.colors`): Point to brand color tokens.

### What you should NOT change

- **Widget types** (`type` fields like `SidebarLayout`, `HierarchyTreeSelector`, `SplitWorkspace`): These map to hardcoded `ComponentFactory` entries. Changing them will crash the app.
- **Binding keys** (`bindings.data_source`, `bindings.selection_target`): These are consumed by `ComponentFactory`. Removing or renaming them may break data wiring.

### Minimal layout change: Update tab labels

```json
{
  "type": "TableView",
  "id": "sub_elements_table",
  "props": {
    "label": "Books",
    ...
  }
}
```

### Minimal layout change: Adjust default split ratio

```json
{
  "props": {
    "default_ratio": 0.35
  }
}
```

---

## 7. Step 5: Rebuild and Test

```bash
cd app_flutter

# Run existing tests (ensure nothing regressed)
flutter test

# Build your target platform
flutter build macos    # macOS
flutter build linux    # Linux
flutter build windows  # Windows
```

### Verify your domain is working

1. Launch the app.
2. Check the sidebar — you should see your root types (e.g., Genre) at the top level.
3. Expand a type — child types should appear (e.g., Books under Genre).
4. Click a child type — the property form should show the fields you defined, grouped by section.
5. Check that required fields show validation, numeric fields respect min/max, and enum fields show a dropdown.

---

## 8. Step 6: (Advanced) Wire a Different Data Source

The platform is not limited to SQLite. You can implement the `DataSource` abstract class to fetch ontology from Firebase, gRPC, REST API, or any other backend.

### The DataSource interface

Defined in `lib/domain/data_source.dart`:

```dart
abstract class DataSource {
  String get name;
  Future<List<TypeDescriptor>> discoverTypes();
  Future<TypeDescriptor?> typeFor(String typeName);
  Future<List<(String, String)>> discoverHierarchy();
}
```

### Example: Firebase Data Source

```dart
import 'package:app_flutter/domain/data_source.dart';
import 'package:app_flutter/domain/type_descriptor.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseDataSource implements DataSource {
  final FirebaseFirestore firestore;

  FirebaseDataSource(this.firestore);

  @override
  String get name => 'firebase';

  @override
  Future<List<TypeDescriptor>> discoverTypes() async {
    final snapshot = await firestore.collection('type_definitions').get();
    final types = <TypeDescriptor>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final typeName = data['type_name'] as String;

      // Fetch attributes
      final attrSnapshot = await firestore
          .collection('type_attributes')
          .where('type_name', isEqualTo: typeName)
          .orderBy('section_order')
          .get();

      final fields = attrSnapshot.docs.map((a) {
        final ad = a.data();
        return FieldDescriptor(
          key: ad['attr_key'] as String,
          label: ad['label'] as String,
          type: ad['attr_type'] as String,
          sectionLabel: ad['section_label'] as String?,
          sectionOrder: ad['section_order'] as int? ?? 0,
          required: (ad['is_required'] as int? ?? 0) == 1,
          minValue: ad['min_value'] as num?,
          maxValue: ad['max_value'] as num?,
          pattern: ad['pattern'] as String?,
          enumOptions: ad['enum_options'] != null
              ? (ad['enum_options'] as List).cast<String>()
              : null,
          enumDisplayNames: ad['enum_display_names'] != null
              ? (ad['enum_display_names'] as List).cast<String>()
              : null,
          defaultValue: ad['default_value'],
        );
      }).toList();

      types.add(TypeDescriptor(
        typeName: typeName,
        displayName: data['display_name'] as String,
        iconName: data['icon_name'] as String? ?? 'insert_drive_file',
        fields: fields,
        childTypes: [],
        parentTypes: [],
      ));
    }

    return types;
  }

  @override
  Future<TypeDescriptor?> typeFor(String typeName) async {
    final doc = await firestore.collection('type_definitions').doc(typeName).get();
    if (!doc.exists) return null;
    // ... (same pattern as discoverTypes but for a single type)
    return null; // placeholder
  }

  @override
  Future<List<(String, String)>> discoverHierarchy() async {
    final snapshot = await firestore.collection('type_relations').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return (
        data['parent_type_name'] as String,
        data['child_type_name'] as String,
      );
    }).toList();
  }
}
```

### Wiring it in

Open `lib/domain/repository_resolver.dart` and add your data source to the switch:

```dart
switch (type) {
  case 'firebase':
    return _createFirebaseAdapter();
  case 'sqlite':
    return _createSqliteAdapter(...);
  default:
    return _createSqliteAdapter(...);
}
```

Then set `repository_type` in `assets/persistence-config.json`:

```json
{
  "repository_type": "firebase"
}
```

### What else you may need

- If your new data source provides _instance data_ (not just schema), implement a custom `AbstractRepository` as well.
- The `RepositoryResolver.resolve()` returns both `(AbstractRepository, DataSource)` — both can be swapped independently.

---

## 9. Example: Library Domain

This section walks through a complete deployment for a small library catalog system.

### 9.1 Ontology

```
Genre ──contains──> Book ──written_by──> Author
                        ──borrowed_by──> Patron ──has_loan──> Loan
```

### 9.2 Seed SQL

Full seed script is shown in [Step 4](#4-step-2-seed-the-database) — here is the condensed version:

```sql
DELETE FROM type_relations;
DELETE FROM type_attributes;
DELETE FROM type_definitions;

INSERT INTO type_definitions VALUES ('Genre', 'Genre', 'category');
INSERT INTO type_definitions VALUES ('Book', 'Book', 'menu_book');
INSERT INTO type_definitions VALUES ('Author', 'Author', 'person');
INSERT INTO type_definitions VALUES ('Patron', 'Patron', 'people');
INSERT INTO type_definitions VALUES ('Loan', 'Loan', 'receipt_long');

INSERT INTO type_relations VALUES (1, 'Genre', 'contains', 'Book', 'Books');
INSERT INTO type_relations VALUES (2, 'Book', 'written_by', 'Author', 'Authors');
INSERT INTO type_relations VALUES (3, 'Book', 'borrowed_by', 'Patron', 'Borrowers');
INSERT INTO type_relations VALUES (4, 'Patron', 'has_loan', 'Loan', 'Loans');

-- Genre fields
INSERT INTO type_attributes (type_name, attr_key, label, attr_type, section_label, section_order, is_required) VALUES ('Genre', 'name', 'Name', 'string', 'Details', 0, 1);
INSERT INTO type_attributes (type_name, attr_key, label, attr_type, section_label, section_order, is_required) VALUES ('Genre', 'description', 'Description', 'string', 'Details', 1, 0);

-- Book fields
INSERT INTO type_attributes (type_name, attr_key, label, attr_type, section_label, section_order, is_required, min_value, max_value) VALUES ('Book', 'title', 'Title', 'string', 'Details', 0, 1, NULL, NULL);
INSERT INTO type_attributes (type_name, attr_key, label, attr_type, section_label, section_order, is_required) VALUES ('Book', 'subtitle', 'Subtitle', 'string', 'Details', 1, 0);
INSERT INTO type_attributes (type_name, attr_key, label, attr_type, section_label, section_order, is_required, min_value, max_value) VALUES ('Book', 'pages', 'Page Count', 'int', 'Details', 2, 0, 1, 10000);
INSERT INTO type_attributes (type_name, attr_key, label, attr_type, section_label, section_order, is_required) VALUES ('Book', 'isbn', 'ISBN-13', 'string', 'Identifiers', 0, 0);
INSERT INTO type_attributes (type_name, attr_key, label, attr_type, section_label, section_order, is_required, min_value, max_value) VALUES ('Book', 'publish_year', 'Publish Year', 'int', 'Details', 3, 0, 1400, 2030);

-- Author fields
INSERT INTO type_attributes (type_name, attr_key, label, attr_type, section_label, section_order, is_required) VALUES ('Author', 'name', 'Full Name', 'string', 'Details', 0, 1);
INSERT INTO type_attributes (type_name, attr_key, label, attr_type, section_label, section_order, is_required) VALUES ('Author', 'birth_year', 'Birth Year', 'int', 'Details', 1, 0);
INSERT INTO type_attributes (type_name, attr_key, label, attr_type, section_label, section_order, is_required) VALUES ('Author', 'nationality', 'Nationality', 'string', 'Details', 2, 0);

-- Patron fields
INSERT INTO type_attributes (type_name, attr_key, label, attr_type, section_label, section_order, is_required) VALUES ('Patron', 'name', 'Name', 'string', 'Details', 0, 1);
INSERT INTO type_attributes (type_name, attr_key, label, attr_type, section_label, section_order, is_required) VALUES ('Patron', 'email', 'Email', 'string', 'Details', 1, 0);
INSERT INTO type_attributes (type_name, attr_key, label, attr_type, section_label, section_order, is_required) VALUES ('Patron', 'phone', 'Phone', 'string', 'Details', 2, 0);
INSERT INTO type_attributes (type_name, attr_key, label, attr_type, section_label, section_order, is_required) VALUES ('Patron', 'member_since', 'Member Since', 'date', 'Details', 3, 0);

-- Loan fields
INSERT INTO type_attributes (type_name, attr_key, label, attr_type, section_label, section_order, is_required) VALUES ('Loan', 'checkout_date', 'Checkout Date', 'date', 'Details', 0, 1);
INSERT INTO type_attributes (type_name, attr_key, label, attr_type, section_label, section_order, is_required) VALUES ('Loan', 'due_date', 'Due Date', 'date', 'Details', 1, 1);
INSERT INTO type_attributes (type_name, attr_key, label, attr_type, section_label, section_order, is_required) VALUES ('Loan', 'returned', 'Returned', 'enum', 'Details', 2, 1);
INSERT INTO type_attributes (type_name, attr_key, label, attr_type, section_label, section_order, is_required) VALUES ('Loan', 'notes', 'Notes', 'string', 'Details', 3, 0);
```

### 9.3 Build Steps

```bash
cd app_flutter

# 1. Regenerate schema
dart run scripts/generate_db.dart

# 2. Seed ontology
sqlite3 assets/properties_db.db < scripts/seed_library.sql

# 3. Verify
sqlite3 assets/properties_db.db "SELECT COUNT(*) AS types FROM type_definitions;"
sqlite3 assets/properties_db.db "SELECT COUNT(*) AS attrs FROM type_attributes;"
sqlite3 assets/properties_db.db "SELECT COUNT(*) AS rels FROM type_relations;"

# 4. Build
flutter build macos
```

### 9.4 Expected Results

| UI Element        | Expected Content                                          |
|-------------------|-----------------------------------------------------------|
| Sidebar           | Top-level: **Genre**. Expand to see **Book**. Expand to see **Author**, **Patron**. |
| Property Form (Book) | Sections: **Details** (title, subtitle, pages, publish year), **Identifiers** (isbn). Title is bold/required. Pages limited to 1–10000. |
| Property Form (Loan) | Fields: checkout_date, due_date, returned (enum dropdown), notes. Checkout/due date are required. |
| Tab Tables        | Under Genre: "Books" tab. Under Book: "Authors", "Borrowers" tabs. Under Patron: "Loans" tab. |

---

## 10. Troubleshooting

### "No type definitions found" — app shows a blank "Item" type

The `RepositoryResolver` counts rows in `type_definitions`. If the count is zero, it falls back to `FallbackDataSource`, which provides a hardcoded `Item` type. **Solution:** Make sure your seed data was written to the correct database file. Verify:

```bash
sqlite3 app_flutter/assets/properties_db.db "SELECT COUNT(*) FROM type_definitions;"
```

If the count is `0`, re-run the seed step.

### The app still shows old types after seeding

The app copies the bundled asset to a support directory on first launch. **Solutions:**
- Delete the cached database: `rm -rf ~/Library/Application\ Support/<bundle-id>/properties_db.db` (macOS).
- Or increment the build number so the app reinstalls fresh.

### SQL error: "UNIQUE constraint failed"

You tried to insert a duplicate `(type_name, attr_key)` pair or a duplicate `(parent_type_name, child_type_name)` pair. Check for duplicates in your seed script.

### Enum fields show as plain text instead of dropdowns

Ensure `attr_type` is exactly `'enum'` and that `enum_options` is a valid JSON array string (e.g., `'["Fiction","Non-Fiction"]'`). The `SqliteDataSource._parseField` method calls `jsonDecode` on `enum_options` — invalid JSON will silently produce `null`.

### "Cannot locate database asset" error on build

Ensure `assets/properties_db.db` exists (even if empty) and is listed in `pubspec.yaml` under `flutter:` → `assets:`:

```yaml
flutter:
  assets:
    - assets/properties_db.db
    - assets/logical-layout.json
```

### Changes to seed data not reflected after rebuild

The Flutter build copies `assets/` files into the bundle. Run `flutter clean` then rebuild:

```bash
flutter clean && flutter pub get && flutter build macos
```

### Sidebar hierarchy looks wrong

The `TreeViewModel` builds the tree in `_buildTree()`: types that never appear as a child in `type_relations` become root nodes. If you want `Book` under `Genre`, make sure a `type_relations` row exists with `parent_type_name = 'Genre'` and `child_type_name = 'Book'`.

### Field not appearing in property form

Check:
1. The `type_name` in `type_attributes` matches exactly (case-sensitive) a `type_name` in `type_definitions`.
2. The `attr_key` is unique within that type.
3. The `SqliteDataSource` query orders by `section_order, id` — fields with `NULL` `section_order` default to `0`.

---

## Appendix A: Reference — Database Schema

The tables created by `scripts/generate_db.dart`:

```
type_definitions
  type_name TEXT PRIMARY KEY
  display_name TEXT NOT NULL
  icon_name TEXT NOT NULL DEFAULT 'insert_drive_file'

type_attributes
  id INTEGER PRIMARY KEY AUTOINCREMENT
  type_name TEXT NOT NULL → type_definitions(type_name)
  attr_key TEXT NOT NULL
  label TEXT NOT NULL
  attr_type TEXT NOT NULL
  section_label TEXT
  section_order INTEGER NOT NULL DEFAULT 0
  is_required INTEGER NOT NULL DEFAULT 0
  min_value REAL
  max_value REAL
  pattern TEXT
  enum_options TEXT
  enum_display_names TEXT
  default_value TEXT
  input_formatters TEXT
  UNIQUE(type_name, attr_key)

type_relations
  id INTEGER PRIMARY KEY AUTOINCREMENT
  parent_type_name TEXT NOT NULL → type_definitions(type_name)
  relation_name TEXT NOT NULL
  child_type_name TEXT NOT NULL → type_definitions(type_name)
  child_label TEXT NOT NULL
  UNIQUE(parent_type_name, child_type_name)
```

## Appendix B: Reference — Material Icon Names

Find icon names at [flutter.github.io/material-icon-font](https://flutter.github.io/material-icon-font/). Use the "snake_case" name (e.g., `menu_book`, `person`, `category`, `dns`, `inventory_2`, `local_hospital`, `warehouse`).
