#!/usr/bin/env python3
"""
YANG-to-LUI JSON Compiler

Build-time script that parses YANG schema files using pyang and outputs
a platform-agnostic logical-layout.json for the generic UI shell.

Usage:
    python3 compile_yang.py --input model.yang --output logical-layout.json

Dependencies:
    pyang (https://github.com/mbj4668/pyang)
    Python 3.8+
"""

import argparse
import json
import os
import re
import sys


# ---------------------------------------------------------------------------
# LUI JSON builder — walks pyang's internal AST directly
# ---------------------------------------------------------------------------

# YANG built-in type → LUI type mapping
YANG_TO_LUI_TYPE = {
    'int8': 'int',
    'int16': 'int',
    'int32': 'int',
    'int64': 'int',
    'uint8': 'int',
    'uint16': 'int',
    'uint32': 'int',
    'uint64': 'int',
    'float32': 'double',
    'float64': 'double',
    'decimal64': 'double',
    'boolean': 'boolean',
    'empty': 'boolean',
    'enumeration': 'enum',
    'string': 'string',
    'binary': 'string',
    'bits': 'string',
    'union': 'string',
}

# Node keywords that are traversed when extracting hierarchy / attributes
CONTAINER_OR_LIST = {'container', 'list'}
LEAF_OR_CHOICE = {'leaf', 'leaf-list', 'choice', 'case', 'uses', 'augment', 'anyxml'}


def resolve_type(type_stmt):
    """
    Resolve a ``type`` substatement to its base LUI type and any
    constraint properties (range, pattern, enum options).

    Params
    ------
    type_stmt : pyang Statement or None
        The ``type`` sub-statement of a leaf node.

    Returns
    -------
    dict with keys ``lui_type``, ``options``, ``minValue``,
    ``maxValue``, ``pattern``.
    """
    result = {
        'lui_type': 'string',
        'options': None,
        'minValue': None,
        'maxValue': None,
        'pattern': None,
    }

    if type_stmt is None:
        return result

    # Walk through typedef layers to reach the base type.
    # Unresolved statements carry children in ``substmts``;
    # validated statements carry them in ``i_children``.
    current = type_stmt
    visited = set()
    while current.keyword == 'typedef':
        if id(current) in visited:
            break
        visited.add(id(current))
        children = getattr(current, 'i_children', None) or current.substmts
        next_type = None
        for c in children:
            if c.keyword == 'type':
                next_type = c
                break
        if next_type is None:
            break
        current = next_type

    type_name = current.arg
    result['lui_type'] = YANG_TO_LUI_TYPE.get(type_name, 'string')

    # Collect constraints from the type's children
    children = getattr(current, 'i_children', None) or current.substmts
    for child in children:
        if child.keyword == 'range':
            lo, hi = _parse_range(child.arg)
            result['minValue'] = lo
            result['maxValue'] = hi
        elif child.keyword == 'pattern':
            result['pattern'] = child.arg
        elif child.keyword == 'enum':
            if result['options'] is None:
                result['options'] = []
            result['options'].append(child.arg)

    return result


def _parse_range(range_str):
    """Parse YANG range ``'68..9216'`` into ``(68, 9216)``."""
    m = re.match(r'\s*(\d+)\s*\.\.\s*(\d+)', str(range_str))
    if m:
        return int(m.group(1)), int(m.group(2))
    return None, None


def _is_mandatory(stmt):
    """Return True when the statement carries ``mandatory true``."""
    for child in stmt.substmts:
        if child.keyword == 'mandatory' and child.arg == 'true':
            return True
    return False


def build_attributes(data_nodes, parent_path=''):
    """
    Walk data-definition statements and produce a flat list of LUI
    attribute definitions.

    The ``key`` for each attribute is its YANG XPath fragment
    (e.g. ``interfaces/interface/mtu``), which aligns perfectly
    with the gNMI telemetry path so that no additional translation
    is needed during Save operations.

    Params
    ------
    data_nodes : list of pyang Statement
        Siblings to walk (containers, lists, leaves …).
    parent_path : str
        Accumulated XPath prefix inherited from ancestor nodes.

    Returns
    -------
    list of dict
    """
    attrs = []

    for node in data_nodes:
        name = node.arg
        current_path = f'{parent_path}/{name}' if parent_path else name

        # Use substmts for unresolved statements (before ctx.validate()),
        # i_children for fully resolved statements.
        children = (getattr(node, 'i_children', None)
                    if getattr(node, 'i_is_validated', False)
                    else node.substmts)

        if node.keyword in LEAF_OR_CHOICE:
            type_stmt = node.search_one('type')
            info = resolve_type(type_stmt)

            attr = {
                'key': current_path.lstrip('/'),
                'label': name.replace('-', ' ').replace('_', ' ').title(),
                'type': info['lui_type'],
                'sectionGroup': parent_path.split('/')[0] if parent_path else 'General',
                'isRequired': _is_mandatory(node),
            }
            if info.get('minValue') is not None:
                attr['minValue'] = info['minValue']
            if info.get('maxValue') is not None:
                attr['maxValue'] = info['maxValue']
            if info.get('pattern') is not None:
                attr['pattern'] = info['pattern']
            if info.get('options') is not None:
                attr['options'] = info['options']

            attrs.append(attr)

        # Walk into container / list / choice / case / uses / augment
        if node.keyword in CONTAINER_OR_LIST:
            subs = [c for c in children
                    if c.keyword in (LEAF_OR_CHOICE | CONTAINER_OR_LIST)]
            attrs.extend(build_attributes(subs, current_path))

        if node.keyword in ('choice', 'case', 'uses', 'augment'):
            subs = [c for c in children
                    if c.keyword in (LEAF_OR_CHOICE | CONTAINER_OR_LIST |
                                     {'choice', 'case', 'uses', 'augment'})]
            attrs.extend(build_attributes(subs, current_path))

    return attrs


def build_hierarchy(data_nodes):
    """
    Walk data-definition statements and produce a nested tree for
    the sidebar ``HierarchyTreeSelector``.

    Only ``container`` and ``list`` nodes produce hierarchy entries;
    leaf nodes are not included since they represent scalar properties
    rather than navigable resources.

    Params
    ------
    data_nodes : list of pyang Statement

    Returns
    -------
    list of dict with ``id``, ``label``, and optional ``children``.
    """
    nodes = []

    for node in data_nodes:
        if node.keyword not in CONTAINER_OR_LIST:
            continue

        name = node.arg
        entry = {
            'id': name,
            'label': name.replace('-', ' ').replace('_', ' ').title(),
        }

        children = (getattr(node, 'i_children', None)
                    if getattr(node, 'i_is_validated', False)
                    else node.substmts)
        subs = [c for c in children
                if c.keyword in (CONTAINER_OR_LIST |
                                 {'choice', 'case', 'uses', 'augment'})]
        sub = build_hierarchy(subs)
        if sub:
            entry['children'] = sub

        nodes.append(entry)

    return nodes


def build_lui_json(data_defs, schema_name='unknown', yang_source=''):
    """
    Assemble the complete ``logical-layout.json`` dictionary.

    Params
    ------
    data_defs : list of pyang Statement
        Top-level data-definition statements from the parsed module.
    schema_name : str
        Module name for the meta section.
    yang_source : str
        Absolute path to the source YANG file.

    Returns
    -------
    dict
    """
    hierarchy = build_hierarchy(data_defs)
    attributes = build_attributes(data_defs)

    return {
        'meta': {
            'version': '1.0.0',
            'schema_name': schema_name,
            'yang_source': yang_source,
        },
        'theme': {
            'modes': ['light', 'dark', 'system'],
        },
        'navigation': {
            'sidebar': {
                'collapsible': True,
                'default_expanded': True,
            },
        },
        'layout': {
            'root_container': {
                'type': 'SidebarLayout',
                'id': 'main_shell',
                'children': [
                    {
                        'type': 'HierarchyTreeSelector',
                        'id': 'resource_tree',
                        'props': {
                            'hierarchy': hierarchy,
                        },
                        'bindings': {
                            'selection_target': 'selected_managed_object',
                        },
                    },
                    {
                        'type': 'SplitWorkspace',
                        'id': 'workspace_split',
                        'props': {
                            'axis': 'horizontal',
                            'resizable': True,
                        },
                        'children': [
                            {
                                'type': 'TopographicalView',
                                'id': 'topology_pane',
                            },
                            {
                                'type': 'TabbedContainer',
                                'id': 'details_and_relations_tab',
                                'children': [
                                    {
                                        'type': 'TableView',
                                        'id': 'sub_elements_table',
                                    },
                                    {
                                        'type': 'TableView',
                                        'id': 'active_alarms_table',
                                    },
                                    {
                                        'type': 'TableView',
                                        'id': 'historical_events_table',
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        },
        'attributes': attributes,
    }


# ---------------------------------------------------------------------------
# Standalone entry point — parses with pyang Python API and writes output
# ---------------------------------------------------------------------------

def parse_yang(input_path):
    """
    Parse a YANG file using pyang's Python API.

    Returns the list of top-level data-definition statements
    (containers, lists, leaves, etc.) extracted from the module.

    Raises ``SystemExit`` on parse failure.
    """
    # Lazy imports so the script can still define the LuiOutputPlugin
    # without pulling pyang in at module level.
    from pyang import context, repository, plugin, statements

    plugin.init([])

    repos = repository.FileRepository(
        os.path.dirname(input_path) if os.path.dirname(input_path) else '.',
        no_path_recurse=True,
    )
    ctx = context.Context(repos)
    # Prevent pyang from scanning system directories by clearing
    # the default search path that includes /var/folders/...
    ctx.opts = argparse.Namespace(input=input_path)

    with open(input_path, 'r') as f:
        text = f.read()

    module = ctx.add_module(input_path, text, primary_module=True)
    if module is None:
        print(f'Error: could not parse YANG file: {input_path}', file=sys.stderr)
        for err in ctx.errors:
            print(f'  {err}', file=sys.stderr)
        sys.exit(1)

    ctx.validate()

    # Return children that are data-definition statements
    return [c for c in module.i_children
            if c.keyword in statements.data_definition_keywords]


def compile_yang(input_path, output_path):
    """Compile a YANG file into ``logical-layout.json``."""
    print(f'Compiling YANG: {input_path}')

    data_defs = parse_yang(input_path)
    schema_name = os.path.splitext(os.path.basename(input_path))[0]

    lui_json = build_lui_json(
        data_defs,
        schema_name=schema_name,
        yang_source=os.path.abspath(input_path),
    )

    with open(output_path, 'w') as f:
        json.dump(lui_json, f, indent=2)

    hierarchy = lui_json['layout']['root_container']['children'][0]['props']['hierarchy']
    attributes = lui_json['attributes']
    print(f'Generated: {output_path}')
    print(f'  Hierarchy nodes: {len(hierarchy)}')
    print(f'  Attributes: {len(attributes)}')


def main():
    parser = argparse.ArgumentParser(
        description='Compile YANG schema into logical-layout.json for the generic UI shell.'
    )
    parser.add_argument('--input', '-i', required=True,
                        help='Path to the input YANG file')
    parser.add_argument('--output', '-o', default='logical-layout.json',
                        help='Output path for the generated JSON')
    args = parser.parse_args()

    if not os.path.isfile(args.input):
        print(f'Error: Input file not found: {args.input}', file=sys.stderr)
        sys.exit(1)

    compile_yang(args.input, args.output)


if __name__ == '__main__':
    main()
