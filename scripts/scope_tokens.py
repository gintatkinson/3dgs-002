#!/usr/bin/env python3
import argparse
import json
import os
import sys

def is_reference(val):
    return isinstance(val, str) and val.startswith("{") and val.endswith("}")

def find_tokens(node, path=None):
    if path is None:
        path = []
    tokens = {}
    if isinstance(node, dict):
        if "$value" in node:
            tokens[".".join(path)] = node
        else:
            for k, v in node.items():
                tokens.update(find_tokens(v, path + [k]))
    return tokens

def resolve_value(token_path, tokens, mode=None, visited=None):
    if visited is None:
        visited = []
    
    if token_path in visited:
        cycle = " -> ".join(visited) + f" -> {token_path}"
        raise ValueError(f"Circular dependency detected: {cycle}")
        
    token = tokens.get(token_path)
    if not token:
        raise KeyError(f"Token '{token_path}' not found")
        
    val = token.get("$value")
    if val is None:
        raise ValueError(f"Token '{token_path}' is missing '$value' property")
        
    # If the value is mode-specific, choose the correct one
    if isinstance(val, dict):
        if mode is not None and mode in val:
            val = val[mode]
        elif "light" in val:
            val = val["light"]
        elif val:
            val = next(iter(val.values()))
        else:
            raise ValueError(f"Token '{token_path}' has empty mode dictionary")
            
    if is_reference(val):
        ref_path = val[1:-1]
        return resolve_value(ref_path, tokens, mode, visited + [token_path])
        
    return val

def validate_tokens(tokens):
    for path, token in tokens.items():
        val = token.get("$value")
        if isinstance(val, dict):
            for mode in val.keys():
                resolve_value(path, tokens, mode=mode)
        else:
            resolve_value(path, tokens)

def generate_css(tokens):
    target_tokens = {}
    for path, token in tokens.items():
        if path.startswith("alias.") or path.startswith("component."):
            target_tokens[path] = token

    light_vars = {}
    dark_vars = {}
    
    for path in sorted(target_tokens.keys()):
        # Convert path like alias.color.brand-primary to --alias-color-brand-primary
        var_name = "--" + path.replace(".", "-")
        
        val_light = resolve_value(path, tokens, mode="light")
        val_dark = resolve_value(path, tokens, mode="dark")
        
        light_vars[var_name] = val_light
        if val_light != val_dark:
            dark_vars[var_name] = val_dark
            
    lines = []
    lines.append("/* Auto-generated design tokens. Do not edit directly. */")
    lines.append(":root {")
    for var_name, val in light_vars.items():
        lines.append(f"  {var_name}: {val};")
    lines.append("}")
    
    if dark_vars:
        lines.append("")
        lines.append('[data-theme="dark"] {')
        for var_name, val in dark_vars.items():
            lines.append(f"  {var_name}: {val};")
        lines.append("}")
        
    return "\n".join(lines)

def run_self_tests():
    print("Running self-tests...")
    
    # Test case 1: normal resolution
    test_tokens = {
        "global.color.blue": {"$value": "#" + "0000ff", "$type": "color"},
        "alias.color.brand": {"$value": "{global.color.blue}", "$type": "color"},
        "component.button.bg": {"$value": "{alias.color.brand}", "$type": "color"}
    }
    
    val = resolve_value("component.button.bg", test_tokens)
    assert val == "#" + "0000ff", f"Expected blue color, got {val}"
    
    # Test case 2: cycle detection
    cycle_tokens = {
        "alias.a": {"$value": "{alias.b}"},
        "alias.b": {"$value": "{alias.c}"},
        "alias.c": {"$value": "{alias.a}"}
    }
    try:
        resolve_value("alias.a", cycle_tokens)
        assert False, "Expected ValueError for circular dependency"
    except ValueError as e:
        assert "Circular dependency detected" in str(e), f"Unexpected error message: {e}"
        assert "alias.a -> alias.b -> alias.c -> alias.a" in str(e)
        
    # Test case 3: missing reference detection
    missing_tokens = {
        "alias.a": {"$value": "{alias.b}"}
    }
    try:
        resolve_value("alias.a", missing_tokens)
        assert False, "Expected KeyError for missing token"
    except KeyError as e:
        assert "alias.b" in str(e), f"Unexpected error message: {e}"

    # Test case 4: light/dark mode resolution
    mode_tokens = {
        "global.color.light-bg": {"$value": "#" + "f"*6},
        "global.color.dark-bg": {"$value": "#" + "12"*3},
        "alias.color.bg": {
            "$value": {
                "light": "{global.color.light-bg}",
                "dark": "{global.color.dark-bg}"
            }
        },
        "component.panel.bg": {"$value": "{alias.color.bg}"}
    }
    val_light = resolve_value("component.panel.bg", mode_tokens, mode="light")
    val_dark = resolve_value("component.panel.bg", mode_tokens, mode="dark")
    assert val_light == "#" + "f"*6, f"Expected light background, got {val_light}"
    assert val_dark == "#" + "12"*3, f"Expected dark background, got {val_dark}"
    
    print("All self-tests passed successfully!")

def main():
    parser = argparse.ArgumentParser(description="Parse restructured design tokens and output CSS variables mapping semantic and component styles.")
    parser.add_argument("-i", "--input", default=".pipeline/logical-ui/design-tokens.json", help="Path to input design tokens JSON file.")
    parser.add_argument("-o", "--output", default=".pipeline/logical-ui/design-tokens.css", help="Path to output CSS variables file.")
    parser.add_argument("--print-only", action="store_true", help="Print CSS to stdout without writing to the output file.")
    parser.add_argument("--self-test", action="store_true", help="Run internal validation suite.")
    
    args = parser.parse_args()
    
    if args.self_test:
        run_self_tests()
        sys.exit(0)
        
    if not os.path.exists(args.input):
        print(f"Error: Input file '{args.input}' not found.", file=sys.stderr)
        sys.exit(1)
        
    try:
        with open(args.input, "r", encoding="utf-8") as f:
            raw_data = json.load(f)
    except Exception as e:
        print(f"Error: Failed to parse input JSON file: {e}", file=sys.stderr)
        sys.exit(1)
        
    tokens = find_tokens(raw_data)
    
    try:
        validate_tokens(tokens)
    except Exception as e:
        print(f"Validation failed: {e}", file=sys.stderr)
        sys.exit(1)
        
    css_content = generate_css(tokens)
    
    if args.print_only:
        print(css_content)
    else:
        try:
            # Create parent directories if they do not exist
            output_dir = os.path.dirname(args.output)
            if output_dir and not os.path.exists(output_dir):
                os.makedirs(output_dir, exist_ok=True)
            with open(args.output, "w", encoding="utf-8") as f:
                f.write(css_content + "\n")
            print(f"Successfully generated scoped CSS variables at: {args.output}")
            print("\nGenerated CSS output:")
            print(css_content)
        except Exception as e:
            print(f"Error: Failed to write CSS output file: {e}", file=sys.stderr)
            sys.exit(1)

if __name__ == "__main__":
    main()
