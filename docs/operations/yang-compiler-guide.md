# YANG Compiler Guide

> Build-time tool that transforms YANG schema files into platform-agnostic
> `logical-layout.json` for the generic UI shell.

## Table of Contents

1. [Overview](#1-overview)
2. [Installation](#2-installation)
3. [Usage](#3-usage)
4. [YANG-to-LUI Mapping Reference](#4-yang-to-lui-mapping-reference)
5. [Generated JSON Structure](#5-generated-json-structure)
6. [Integrating with the Flutter App](#6-integrating-with-the-flutter-app)
7. [Example: Compiling a Network Model](#7-example-compiling-a-network-model)
8. [Limitations](#8-limitations)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Overview

The YANG compiler (`scripts/compile_yang.py`) is the
build-time component of the **YANG-to-LUI (Logical UI) Translation Pipeline**
mandated by the persistence architecture blueprint.

**YANG** (RFC 7950) is the single source of truth for data models in telecom
and SDN environments. Network equipment vendors ship YANG modules that define
containers, lists, leaves, types, ranges, and enumerations for every managed
resource (interfaces, chassis, sensors, routing protocols, etc.).

The compiler runs inside CI/CD using **pyang** — an open-source Python YANG
validator and parser. It walks pyang's internal AST and emits a
`logical-layout.json` file that:

- Drives the **sidebar hierarchy** (tree navigation of managed objects).
- Defines **attribute definitions** (field labels, types, validation
  constraints, and enum options) for the generic `PropertyGrid` widget.
- Carries **layout structure** (panes, tabs, topology map) for the UI shell.

Key architectural principles:

| Principle | Rationale |
|---|---|
| **Build-time transformation** | No YANG parser runs in the browser or Flutter isolate. The heavy AST work happens once. |
| **YANG path as UI key** | Each attribute's `key` is its absolute YANG XPath (e.g. `interfaces/interface/state/mtu`). Save payloads map directly to gNMI telemetry paths with zero translation. |
| **Zero hand-edited JSON** | The output is regenerated from source YANG on every build. Manual edits to `logical-layout.json` would be overwritten. |
| **Platform-agnostic output** | The same `logical-layout.json` is consumed by both the Flutter desktop app and the React web shell. |

---

## 2. Installation

### Prerequisites

- **Python 3.8+**
- **pip** (Python package installer)
- **pyang** — the YANG parser library

### Install pyang

```bash
pip install pyang
```

Verify the installation:

```bash
pyang --version
```

### Clone the repository

```bash
git clone <repository-url>
cd digital-pipeline-repo
```

### Test that the compiler is importable

```bash
python3 scripts/compile_yang.py --help
```

Expected output:

```
usage: compile_yang.py [-h] --input INPUT [--output OUTPUT]

Compile YANG schema into logical-layout.json for the generic UI shell.

optional arguments:
  -h, --help            show this help message and exit
  --input INPUT, -i INPUT
                        Path to the input YANG file
  --output OUTPUT, -o OUTPUT
                        Output path for the generated JSON
```

---

## 3. Usage

### Basic command

```bash
python3 scripts/compile_yang.py \
  --input path/to/model.yang \
  --output assets/logical-layout.json
```

### Arguments

| Argument | Short | Required | Default | Description |
|---|---|---|---|---|
| `--input` | `-i` | Yes | — | Path to a `.yang` file |
| `--output` | `-o` | No | `logical-layout.json` | Path for the generated JSON |

### Typical workflow

1. Place your YANG file(s) in a directory known to the build system (e.g.
   `yang-models/`).
2. Run the compiler with the primary YANG module as input.
3. The compiler uses pyang's `FileRepository` to resolve `import` and
   `include` statements relative to the input file's directory.
4. The output `logical-layout.json` replaces the existing asset in
   `app_flutter/assets/`.

### CI/CD integration

Add a build step to your pipeline (GitHub Actions, GitLab CI, Jenkins):

```yaml
# .github/workflows/build.yml (example snippet)
- name: Compile YANG models
  run: |
    pip install pyang
    python3 scripts/compile_yang.py \
      --input yang-models/openconfig-interfaces.yang \
      --output app_flutter/assets/logical-layout.json
```

The generated JSON is then bundled into the Flutter or React artifact as a
static asset.

---

## 4. YANG-to-LUI Mapping Reference

The compiler maps YANG constructs to LUI JSON properties using the following
rules. These rules are implemented in `scripts/compile_yang.py`.

### 4.1. Hierarchy Mapping

| YANG Construct | LUI JSON Output | Example |
|---|---|---|
| `container system` | Hierarchy tree node `System` | `{"id": "system", "label": "System"}` |
| `list interface` | Hierarchy tree node `Interface` | `{"id": "interface", "label": "Interface"}` |
| Nested `container` / `list` | `children` array on parent node | `{"children": [{"id": "state", "label": "State"}]}` |

Only `container` and `list` nodes produce hierarchy entries. Leaf nodes are
excluded since they represent scalar properties rather than navigable
resources.

### 4.2. Attribute Mapping

| YANG Construct | LUI Attribute Property | Example |
|---|---|---|
| `leaf name { type string; }` | Attribute `key` + `type: "string"` | `{"key": "system/name", "type": "string"}` |
| `leaf mtu { type uint32; }` | `type: "int"` | `{"type": "int"}` |
| `leaf voltage { type float64; }` | `type: "double"` | `{"type": "double"}` |
| `leaf enabled { type boolean; }` | `type: "boolean"` | `{"type": "boolean"}` |
| `uint32 { range "68..9216"; }` | `minValue` / `maxValue` | `{"minValue": 68, "maxValue": 9216}` |
| `pattern '[A-Z]{2}';` | `pattern` | `{"pattern": "[A-Z]{2}"}` |
| `enumeration { enum UP; enum DOWN; }` | `options` array | `{"options": ["UP", "DOWN"]}` |
| `mandatory true` | `isRequired: true` | `{"isRequired": true}` |
| `container interfaces { leaf name; }` | `sectionGroup: "interfaces"` | `{"sectionGroup": "interfaces"}` |

### 4.3. YANG Built-in Type Mapping

| YANG Type | LUI Type | Notes |
|---|---|---|
| `int8`, `int16`, `int32`, `int64` | `int` | All signed ints map to `int` |
| `uint8`, `uint16`, `uint32`, `uint64` | `int` | All unsigned ints map to `int` |
| `float32`, `float64`, `decimal64` | `double` | All floating-point types map to `double` |
| `boolean`, `empty` | `boolean` | `empty` behaves as a boolean presence |
| `enumeration` | `enum` | Options extracted from `enum` substatements |
| `string`, `binary`, `bits`, `union` | `string` | Complex types degrade to `string` |

### 4.4. Label Generation

Node and leaf names are converted to human-readable labels by replacing hyphens
and underscores with spaces and applying title case:

| YANG Name | LUI Label |
|---|---|
| `admin-status` | `Admin Status` |
| `max_voltage` | `Max Voltage` |
| `mtu` | `Mtu` |
| `hostname` | `Hostname` |

---

## 5. Generated JSON Structure

The compiler's `build_lui_json()` function assembles a dictionary with five
top-level sections: `meta`, `theme`, `navigation`, `layout`, and `attributes`.

### Full structure

```json
{
  "meta": {
    "version": "1.0.0",
    "schema_name": "openconfig-interfaces",
    "yang_source": "/abs/path/to/openconfig-interfaces.yang"
  },
  "theme": {
    "modes": ["light", "dark", "system"]
  },
  "navigation": {
    "sidebar": {
      "collapsible": true,
      "default_expanded": true
    }
  },
  "layout": {
    "root_container": {
      "type": "SidebarLayout",
      "id": "main_shell",
      "children": [
        {
          "type": "HierarchyTreeSelector",
          "id": "resource_tree",
          "props": {
            "hierarchy": []
          },
          "bindings": {
            "selection_target": "selected_managed_object"
          }
        },
        {
          "type": "SplitWorkspace",
          "id": "workspace_split",
          "props": {
            "axis": "horizontal",
            "resizable": true
          },
          "children": [
            {
              "type": "TopographicalView",
              "id": "topology_pane"
            },
            {
              "type": "TabbedContainer",
              "id": "details_and_relations_tab",
              "children": [
                {
                  "type": "TableView",
                  "id": "sub_elements_table"
                },
                {
                  "type": "TableView",
                  "id": "active_alarms_table"
                },
                {
                  "type": "TableView",
                  "id": "historical_events_table"
                }
              ]
            }
          ]
        }
      ]
    }
  },
  "attributes": []
}
```

### 5.1. Meta Section

```json
"meta": {
  "version": "1.0.0",
  "schema_name": "openconfig-interfaces",
  "yang_source": "/home/ci/yang-models/openconfig-interfaces.yang"
}
```

| Field | Description |
|---|---|
| `version` | Always `"1.0.0"` (hardcoded in the compiler) |
| `schema_name` | Basename of the input YANG file without extension |
| `yang_source` | Absolute filesystem path to the source YANG file (for audit trail) |

### 5.2. Theme Section

```json
"theme": {
  "modes": ["light", "dark", "system"]
}
```

Currently static. The `modes` array advertises support for light, dark, and
system-follow themes. Future versions may read theme tokens from YANG module
annotations.

### 5.3. Navigation Section

```json
"navigation": {
  "sidebar": {
    "collapsible": true,
    "default_expanded": true
  }
}
```

Static sidebar configuration. The `hierarchy` array is embedded inside the
layout section (see below) rather than here, because it needs to live at the
widget-props level consumed by `ComponentFactory`.

### 5.4. Layout Section

The layout section is a **fixed shell** produced by every compilation. Its
structure never changes — only the `hierarchy` array inside the
`HierarchyTreeSelector` props is populated dynamically.

```json
"layout": {
  "root_container": {
    "type": "SidebarLayout",
    "id": "main_shell",
    "children": [
      {
        "type": "HierarchyTreeSelector",
        "id": "resource_tree",
        "props": {
          "hierarchy": [
            {
              "id": "interfaces",
              "label": "Interfaces",
              "children": [
                {
                  "id": "interface",
                  "label": "Interface",
                  "children": [
                    {
                      "id": "state",
                      "label": "State"
                    }
                  ]
                }
              ]
            }
          ]
        },
        "bindings": {
          "selection_target": "selected_managed_object"
        }
      },
      {
        "type": "SplitWorkspace",
        "id": "workspace_split",
        "props": {
          "axis": "horizontal",
          "resizable": true
        },
        "children": [
          { "type": "TopographicalView", "id": "topology_pane" },
          {
            "type": "TabbedContainer",
            "id": "details_and_relations_tab",
            "children": [
              { "type": "TableView", "id": "sub_elements_table" },
              { "type": "TableView", "id": "active_alarms_table" },
              { "type": "TableView", "id": "historical_events_table" }
            ]
          }
        ]
      }
    ]
  }
}
```

The hierarchy tree is built by `build_hierarchy()` which recursively walks
`container` and `list` nodes. Each node has:

| Field | Description |
|---|---|
| `id` | YANG node name (e.g. `"interface"`) |
| `label` | Title-cased display name (e.g. `"Interface"`) |
| `children` | Optional nested nodes (present only when the node has child containers or lists) |

### 5.5. Attributes Section

The `attributes` array is a flat list of all leaf and leaf-list nodes found in
the YANG module, each represented as an attribute definition:

```json
"attributes": [
  {
    "key": "interfaces/interface/name",
    "label": "The Name Of The Interface",
    "type": "string",
    "sectionGroup": "interfaces",
    "isRequired": false
  },
  {
    "key": "interfaces/interface/state/mtu",
    "label": "The Maximum Transmission Unit",
    "type": "int",
    "sectionGroup": "state",
    "isRequired": true,
    "minValue": 68,
    "maxValue": 9216
  },
  {
    "key": "interfaces/interface/state/admin-status",
    "label": "The Administrative Status Of The Interface",
    "type": "enum",
    "sectionGroup": "state",
    "isRequired": false,
    "options": ["UP", "DOWN"]
  }
]
```

#### Attribute definition fields

| Field | Required | Type | Description |
|---|---|---|---|
| `key` | Always | `string` | Absolute YANG XPath (e.g. `interfaces/interface/state/mtu`). Used as the JSON key for Save payloads and aligns with gNMI telemetry paths. |
| `label` | Always | `string` | Human-readable label derived from the YANG node name. |
| `type` | Always | `string` | LUI type: `"string"`, `"int"`, `"double"`, `"boolean"`, `"enum"`. |
| `sectionGroup` | Always | `string` | The parent container's name (first path segment). Fields are grouped under this in the property grid. |
| `isRequired` | Always | `bool` | `true` when the YANG leaf has `mandatory true`. |
| `minValue` | Conditional | `number` | Present when the YANG type has a `range` with a lower bound. |
| `maxValue` | Conditional | `number` | Present when the YANG type has a `range` with an upper bound. |
| `pattern` | Conditional | `string` | Present when the YANG type has a `pattern` constraint. |
| `options` | Conditional | `string[]` | Present for `enumeration` types. Lists all `enum` value names. |

---

## 6. Integrating with the Flutter App

### 6.1. Replace the Generated File

After compiling the YANG model, copy the output to the Flutter app's asset
directory:

```bash
cp logical-layout.json app_flutter/assets/logical-layout.json
```

Or point the compiler directly:

```bash
python3 scripts/compile_yang.py \
  --input yang-models/openconfig-interfaces.yang \
  --output app_flutter/assets/logical-layout.json
```

### 6.2. Understand the Data Flow

The Flutter app consumes the generated file in two ways:

1. **Layout shell** — The `layout` section is parsed by `ComponentFactory` to
   instantiate the sidebar, workspace split, topology pane, and tabbed
   containers. The hierarchy tree populates the `HierarchyTreeSelector` widget.

2. **Attribute schemas** — The `attributes` array is consumed at runtime by
   the generic `PropertyGrid` widget. The file `asset/logical-layout.json` is
   read on startup, deserialized into `AttributeDefinition` objects, and used
   to render form fields dynamically.

### 6.3. Working with SQLite and TypeDescriptors

Per the [Runtime Metadata Architecture Blueprint](../architecture/runtime-metadata-blueprint.md),
the app also supports runtime schema discovery via `DataSource.discoverTypes()`.
When using the SQLite-backed `SqliteDataSource`, the metadata tables
(`type_definitions`, `type_attributes`, `type_relations`) must be populated.

If your YANG compilation is part of a CI/CD pipeline that also seeds the SQLite
database, run the database generation script after replacing the JSON:

```bash
cd app_flutter
dart run scripts/generate_db.dart
```

> **Note:** `generate_db.dart` creates the SQLite schema tables but does **not**
> insert seed data. You must still seed `type_definitions`, `type_attributes`,
> and `type_relations` via SQL or a Dart seed script. The `logical-layout.json`
> `attributes` array and the DB schema are complementary: the JSON provides the
> initial layout and attribute definitions for the static shell, while the DB
> supports runtime discovery for swappable data sources.

### 6.4. Verify the Integration

```bash
cd app_flutter
flutter test
flutter build macos   # or linux, windows, web
```

Launch the app and confirm:

- The sidebar tree matches the YANG container/list hierarchy.
- Selecting a tree node shows the correct attribute fields in the property
  form.
- Numeric fields enforce `minValue`/`maxValue` constraints.
- Enum fields show dropdowns with the YANG enumeration values.
- Required fields are marked and block Save when empty.

---

## 7. Example: Compiling a Network Model

This section walks through compiling an OpenConfig YANG file and inspecting the
output.

### 7.1. Prepare a YANG File

Create a minimal YANG module, for example `example-system.yang`:

```yang
module example-system {
  yang-version 1.1;
  namespace "urn:example:system";
  prefix "sys";

  container system {
    leaf hostname {
      type string;
      mandatory true;
    }

    leaf uptime {
      type uint64;
    }

    container dns {
      leaf primary-server {
        type string;
      }
      leaf secondary-server {
        type string;
      }
    }

    container logging {
      leaf severity {
        type enumeration {
          enum DEBUG;
          enum INFO;
          enum WARN;
          enum ERROR;
          enum CRITICAL;
        }
        mandatory true;
      }
      leaf max-log-size {
        type uint32 {
          range "1..1048576";
        }
      }
    }
  }
}
```

### 7.2. Run the Compiler

```bash
python3 scripts/compile_yang.py \
  --input example-system.yang \
  --output example-logical-layout.json
```

Expected console output:

```
Compiling YANG: example-system.yang
Generated: example-logical-layout.json
  Hierarchy nodes: 1
  Attributes: 5
```

### 7.3. Inspect the Generated Hierarchy

Open `example-logical-layout.json` and check the hierarchy section:

```json
{
  "type": "HierarchyTreeSelector",
  "id": "resource_tree",
  "props": {
    "hierarchy": [
      {
        "id": "system",
        "label": "System",
        "children": [
          {
            "id": "dns",
            "label": "Dns",
            "children": []
          },
          {
            "id": "logging",
            "label": "Logging",
            "children": []
          }
        ]
      }
    ]
  }
}
```

Note: `children` arrays are only present when a node has at least one
container or list child. The `dns` and `logging` containers appear as children
of `system`, but since they contain no sub-containers, their `children` arrays
are empty (or absent in the JSON output).

### 7.4. Inspect the Generated Attributes

```json
"attributes": [
  {
    "key": "system/hostname",
    "label": "Hostname",
    "type": "string",
    "sectionGroup": "system",
    "isRequired": true
  },
  {
    "key": "system/uptime",
    "label": "Uptime",
    "type": "int",
    "sectionGroup": "system",
    "isRequired": false
  },
  {
    "key": "system/dns/primary-server",
    "label": "Primary Server",
    "type": "string",
    "sectionGroup": "system",
    "isRequired": false
  },
  {
    "key": "system/dns/secondary-server",
    "label": "Secondary Server",
    "type": "string",
    "sectionGroup": "system",
    "isRequired": false
  },
  {
    "key": "system/logging/severity",
    "label": "Severity",
    "type": "enum",
    "sectionGroup": "system",
    "isRequired": true,
    "options": ["DEBUG", "INFO", "WARN", "ERROR", "CRITICAL"]
  },
  {
    "key": "system/logging/max-log-size",
    "label": "Max Log Size",
    "type": "int",
    "sectionGroup": "system",
    "isRequired": false,
    "minValue": 1,
    "maxValue": 1048576
  }
]
```

### 7.5. Verify in the Flutter App

1. Copy the file: `cp example-logical-layout.json app_flutter/assets/logical-layout.json`
2. Run `cd app_flutter && dart run scripts/generate_db.dart` (if using SQLite DataSource).
3. Build and launch: `flutter build macos && open build/macos/Build/Products/Debug/app_flutter.app`
4. In the sidebar you should see a single **System** node.
5. Expand System to see **Dns** and **Logging** sub-nodes.
6. Click **System** — the property form should show `Hostname` (required) and
   `Uptime`.
7. Click **Logging** — the form shows `Severity` (required, dropdown with 5
   options) and `Max Log Size` (integer, min 1, max 1048576).

---

## 8. Limitations

### 8.1. Supported Constructs

The compiler currently extracts:

| YANG Construct | Supported | Notes |
|---|---|---|
| `container` | Yes | Produces hierarchy nodes |
| `list` | Yes | Produces hierarchy nodes |
| `leaf` | Yes | Produces attribute definitions |
| `leaf-list` | Yes | Treated as a single-valued leaf (no array-of-values yet) |

### 8.2. Not Yet Supported

| YANG Construct | Status | Impact |
|---|---|---|
| `choice` / `case` | Not mapped | Choice nodes are walked during hierarchy traversal but produce no attribute entries. |
| `identity` | Not resolved | Identity references are not dereferenced; the leaf type defaults to `string`. |
| `typedef` | Partially resolved | Typedef indirection is followed (up to a cycle guard of 5 hops), but only base type and constraints are extracted. If a typedef references an identity or union, resolution degrades to `string`. |
| `augment` | Walked but not specialized | Augment targets are not resolved; child nodes of augment statements are extracted as if they were inline. |
| `deviation` | Ignored | Deviation statements are not parsed. Deviated constraints must be applied to the base model before compilation. |
| `rpc` / `action` | Ignored | RPC input/output nodes are not included in the hierarchy or attributes. |
| `notification` | Ignored | Notification content is not extracted. |
| `anyxml` / `anydata` | Ignored | These schema-less nodes are skipped. |
| `when` / `if-feature` | Ignored | Conditional nodes are not filtered. All nodes are emitted regardless of feature/condition. |
| YANG 1.1 `augment` in submodules | Partial | Submodule resolution depends on pyang's repository; if the submodule file is not found, the augment is silently dropped. |

### 8.3. Semantic Gaps

| Gap | Description |
|---|---|
| **No cross-module resolution** | The compiler parses a single primary module. Imported types from other modules are resolved only if the imported file is in the same directory. |
| **No key extraction** | The `key` statement on `list` nodes is not extracted as a separate property. |
| **No default values** | The `default` statement on leaf nodes is not mapped to `defaultValue` in the attribute definition. |
| **No units** | The `units` statement is not included in the output. |
| **No description** | The `description` statement is not carried into labels. Labels are derived solely from the node name via title-casing. |
| **No ordered-by / min-elements / max-elements** | List constraints are not mapped. |

---

## 9. Troubleshooting

### Error: `Could not parse YANG file`

**Cause**: pyang encountered a syntax error or an unresolved import.

**Solution**:
- Validate the YANG file first: `pyang --yang-validate path/to/model.yang`
- Ensure all imported YANG modules are in the same directory or in pyang's
  module search path.
- Check for YANG 1.1 features that pyang may not fully support.

```bash
pyang --errors path/to/model.yang
```

### Error: `Input file not found`

**Cause**: The `--input` path does not point to an existing file.

**Solution**: Use an absolute path or a relative path from the working directory:

```bash
python3 scripts/compile_yang.py \
  --input $(pwd)/yang-models/model.yang \
  --output logical-layout.json
```

### Error: `pyang` module not found

**Cause**: pyang is not installed or not in the Python path.

**Solution**:

```bash
pip install pyang
python3 -c "from pyang import context; print('OK')"
```

### Generated JSON has no hierarchy nodes

**Cause**: The YANG module defines only top-level leaves or uses constructs the
compiler does not recognize as containers/lists.

**Solution**:
- Verify the module contains `container` or `list` statements at the top level.
- Check for typos in the YANG file.
- Run `pyang -f tree path/to/model.yang` to see pyang's view of the module
  structure.

### Generated JSON has no attributes

**Cause**: All data-definition nodes are either unsupported (`rpc`,
`notification`, `anydata`) or the module only defines `identity`/`typedef`
without `leaf`/`leaf-list`.

**Solution**: Add a `container` with `leaf` children to your YANG model.

### Enum options appear as strings in the UI instead of a dropdown

**Cause**: The `type` field in the attribute JSON is `"string"` instead of
`"enum"`.

**Solution**: Check that the YANG type is `enumeration` and that `enum`
substatements exist. The compiler maps `enumeration` to `"enum"` (line 42 of
`compile_yang.py`). If you see `"type": "string"`, the type name is not
`enumeration` — verify the YANG source.

### Ranges are not reflected in the output

**Cause**: The `range` substatement is missing or uses non-numeric bounds.

**Solution**: The `_parse_range()` function only handles `"min..max"` patterns
with integer bounds. Ranges like `"1..max"` (with keyword bounds) are not
parsed. Ensure the range uses concrete integers:

```yang
leaf mtu {
  type uint32 {
    range "68..9216";   // ✓ parsed correctly
  }
}
```

### The Flutter app still shows old hierarchy after replacing the JSON

**Cause**: Flutter caches assets. The old bundled `logical-layout.json` is
still in the build output or device storage.

**Solution**:

```bash
cd app_flutter
flutter clean
flutter pub get
flutter build macos
```

If the app is running on a device, uninstall and reinstall, or increment the
build number.

### Generated JSON is valid but the property grid shows wrong fields

**Cause**: The runtime `DataSource` is reading from SQLite metadata tables
instead of (or in addition to) `logical-layout.json`. The `attributes` array
in the JSON is only consumed by the fallback path.

**Solution**:
- Check which `DataSource` is active (see `persistence-config.json`).
- If using `SqliteDataSource`, seed the `type_attributes` table with the same
  attribute definitions that the compiler generated.
- If using the JSON-only path, ensure the `DataSource` fallback returns the
  `attributes` from `logical-layout.json`.

### "SectionGroup" mismatch between YANG and expected UI grouping

**Cause**: The `sectionGroup` is set to the first path segment of the key
(e.g., `interfaces/interface/state/mtu` → sectionGroup `"interfaces"`). If you
expect attributes to be grouped by their immediate parent instead, the compiler
does not currently support this customization.

**Solution**: Either adjust your YANG module structure to match the desired
grouping, or post-process the generated JSON to reassign `sectionGroup` values.
