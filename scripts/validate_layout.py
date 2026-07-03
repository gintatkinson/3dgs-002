#!/usr/bin/env python3
import json
import os
import sys

def main():
    script_dir = os.path.dirname(os.path.realpath(__file__))
    repo_root = os.path.dirname(script_dir)
    file_path = os.path.join(repo_root, 'app_flutter', 'assets', 'logical-layout.json')

    if not os.path.exists(file_path):
        print(f"Error: logical-layout.json not found at {file_path}", file=sys.stderr)
        sys.exit(1)

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON document: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading file: {e}", file=sys.stderr)
        sys.exit(1)

    # 1. Verify basic key structures
    if 'layout' not in data:
        print("Error: Missing 'layout' key in JSON root.", file=sys.stderr)
        sys.exit(1)
    if 'root_container' not in data['layout']:
        print("Error: Missing 'root_container' in 'layout'.", file=sys.stderr)
        sys.exit(1)
    if 'theme' not in data:
        print("Error: Missing 'theme' key in JSON root.", file=sys.stderr)
        sys.exit(1)

    theme = data['theme']
    if not isinstance(theme, dict):
        print("Error: 'theme' must be a JSON object.", file=sys.stderr)
        sys.exit(1)

    modes = theme.get('modes')
    if not isinstance(modes, list) or not all(isinstance(m, str) for m in modes):
        print("Error: theme.modes must be a list of strings.", file=sys.stderr)
        sys.exit(1)

    colors = theme.get('colors')
    if not isinstance(colors, dict):
        print("Error: theme.colors must be a JSON object.", file=sys.stderr)
        sys.exit(1)

    # 2. Check layout node ID uniqueness
    seen_ids = set()

    def check_reference_string(val, path_str):
        if not isinstance(val, str):
            return
        # If it looks like a token/spacing/color/theme reference
        if val.startswith('token:') or val.startswith('token.') or val.startswith('color.') or val.startswith('spacing.'):
            # Validate structure
            if val.startswith('token:'):
                rest = val[len('token:'):]
                if not rest or '.' not in rest:
                    print(f"Error: Malformed token reference '{val}' at '{path_str}'. Expected 'token:group.key'", file=sys.stderr)
                    sys.exit(1)
            elif val.startswith('color.'):
                rest = val[len('color.'):]
                if not rest or '.' not in rest:
                    print(f"Error: Malformed color reference '{val}' at '{path_str}'. Expected 'color.group.key'", file=sys.stderr)
                    sys.exit(1)
            elif val.startswith('spacing.'):
                rest = val[len('spacing.'):]
                if not rest:
                    print(f"Error: Malformed spacing reference '{val}' at '{path_str}'. Expected 'spacing.key'", file=sys.stderr)
                    sys.exit(1)
            elif val.startswith('token.'):
                rest = val[len('token.'):]
                if not rest or '.' not in rest:
                    print(f"Error: Malformed token reference '{val}' at '{path_str}'. Expected 'token.group.key'", file=sys.stderr)
                    sys.exit(1)

    def traverse_layout(node, path_str="layout.root_container"):
        if not isinstance(node, dict):
            return

        node_type = node.get('type')
        node_id = node.get('id')

        # Every layout node (an object with type) should have a unique ID
        if node_type is not None or node_id is not None:
            if node_id is None:
                print(f"Error: Layout node of type '{node_type}' at '{path_str}' is missing an 'id'.", file=sys.stderr)
                sys.exit(1)
            if not isinstance(node_id, str) or not node_id.strip():
                print(f"Error: Layout node ID must be a non-empty string at '{path_str}', got: {node_id}", file=sys.stderr)
                sys.exit(1)
            if node_id in seen_ids:
                print(f"Error: Duplicate layout node ID found: '{node_id}' at '{path_str}'", file=sys.stderr)
                sys.exit(1)
            seen_ids.add(node_id)

        # Validate structured references in any keys/values recursively
        for key, val in node.items():
            current_path = f"{path_str}.{key}"
            if isinstance(val, str):
                check_reference_string(val, current_path)
            elif isinstance(val, dict):
                # If it's a dict containing mode specific mappings
                for k, v in val.items():
                    if k in modes and isinstance(v, str):
                        check_reference_string(v, f"{current_path}.{k}")
                    elif isinstance(v, (dict, list)):
                        traverse_layout(v, f"{current_path}.{k}")
            elif isinstance(val, list):
                for idx, item in enumerate(val):
                    if isinstance(item, str):
                        check_reference_string(item, f"{current_path}[{idx}]")
                    elif isinstance(item, dict):
                        traverse_layout(item, f"{current_path}[{idx}]")

    # Validate theme block references specifically
    for col_key, col_val in colors.items():
        col_path = f"theme.colors.{col_key}"
        if isinstance(col_val, str):
            check_reference_string(col_val, col_path)
        elif isinstance(col_val, dict):
            for m_key, m_val in col_val.items():
                if m_key not in modes:
                    print(f"Error: Mode '{m_key}' in '{col_path}' is not defined in modes list {modes}", file=sys.stderr)
                    sys.exit(1)
                if not isinstance(m_val, str):
                    print(f"Error: Mode value in '{col_path}.{m_key}' must be a string reference.", file=sys.stderr)
                    sys.exit(1)
                check_reference_string(m_val, f"{col_path}.{m_key}")
        else:
            print(f"Error: theme.colors.{col_key} must be a string or a mode-mapping dict.", file=sys.stderr)
            sys.exit(1)

    # Validate typography fonts specifically
    typography = theme.get('typography')
    if typography is not None:
        if isinstance(typography, dict):
            fonts = typography.get('fonts')
            if isinstance(fonts, list):
                for idx, font in enumerate(fonts):
                    if isinstance(font, str):
                        check_reference_string(font, f"theme.typography.fonts[{idx}]")

    # Traverse layout hierarchy starting from root_container
    root_container = data['layout']['root_container']
    traverse_layout(root_container)

    print("Success: Layout validation completed successfully.", file=sys.stdout)
    sys.exit(0)

if __name__ == '__main__':
    main()
