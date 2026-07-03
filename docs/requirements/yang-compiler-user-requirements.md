# YANG Compiler: User Requirements & Acceptance Tests

## User Story

As a domain engineer, I want to take a YANG data model file and automatically generate a working UI layout so that I don't have to manually edit `logical-layout.json` or write any Dart/Flutter code.

## Acceptance Criteria

### AC1: Basic Compilation
**Given** a valid YANG file with `container`, `list`, `leaf`, and `enumeration` constructs
**When** I run `compile_yang.py --input mymodel.yang --output layout.json`
**Then** the output file contains a valid `logical-layout.json` with:
- A tree hierarchy reflecting the YANG container/list nesting
- Attribute definitions for every leaf with correct types
- Enum options extracted from YANG enumeration statements
- Range constraints from YANG range statements

### AC2: Type Mapping
**Given** a YANG leaf with type `uint32` and a range constraint
**When** compiled
**Then** the output attribute has `type: "int"` and `minValue`/`maxValue` matching the YANG range

**Given** a YANG leaf with type `enumeration`
**When** compiled
**Then** the output attribute has `type: "enum"` and an `options` array with all enum values

### AC3: Hierarchy Preservation
**Given** a YANG model with nested containers (e.g., `system > interfaces > interface`)
**When** compiled
**Then** the output `hierarchy` preserves the nesting relationship as parent-child tree nodes

### AC4: Mandatory Fields
**Given** a YANG leaf with `mandatory true`
**When** compiled
**Then** the output attribute has `isRequired: true`

### AC5: Error Handling
**Given** an invalid YANG file (syntax error, missing file)
**When** compiled
**Then** the script exits with a non-zero exit code and prints a descriptive error message

### AC6: No Manual Editing
**Given** a generated `logical-layout.json`
**When** loaded by the Flutter app
**Then** the app renders the correct tree hierarchy, property fields with correct types, and validation constraints without any manual editing of the JSON

## Verification Commands

```bash
# AC1: Basic compilation
python3 scripts/compile_yang.py \
  --input /tmp/test-model.yang \
  --output /tmp/test-output.json && \
python3 -c "
import json
with open('/tmp/test-output.json') as f:
    d = json.load(f)
assert len(d['attributes']) > 0, 'No attributes generated'
assert len(d['layout']['root_container']['children'][0]['props']['hierarchy']) > 0, 'No hierarchy'
print('AC1 PASS')
"

# AC2: Type mapping
python3 -c "
import json
with open('/tmp/test-output.json') as f:
    d = json.load(f)
mtu = next(a for a in d['attributes'] if a['key'].endswith('mtu'))
assert mtu['type'] == 'int', f'Expected int, got {mtu[\"type\"]}'
assert mtu['minValue'] == 68
assert mtu['maxValue'] == 9216
admin = next(a for a in d['attributes'] if a['key'].endswith('admin-status'))
assert admin['type'] == 'enum'
assert 'UP' in admin['options']
print('AC2 PASS')
"

# AC5: Error on invalid file
python3 scripts/compile_yang.py \
  --input /tmp/nonexistent.yang \
  --output /tmp/test-output.json 2>&1 && echo 'FAIL: Should have errored' || echo 'AC5 PASS: Correctly errored'

# AC6: Generated file matches expected structure
python3 -c "
import json
with open('/tmp/test-output.json') as f:
    d = json.load(f)
required_keys = {'meta', 'theme', 'navigation', 'layout', 'attributes'}
assert required_keys.issubset(d.keys()), f'Missing keys: {required_keys - d.keys()}'
print('AC6 PASS')
"
```
