#!/usr/bin/env python3
"""
Verify downstream project baseline conformance.
Asserts baseline files exist, validates type compatibility with mandated domain classes,
and runs the build/test commands ('npm run build' for React, 'flutter analyze && flutter test' for Flutter).
"""

import argparse
import json
import os
import re
import subprocess
import sys

# Mandated domain classes/interfaces to check in types.ts or types.dart
MANDATED_CLASSES = [
    "Velocity",
    "TemporalContext",
    "PhysicalAddress",
    "LocationType",
    "LocationHierarchy",
    "RackLocation",
    "Rack",
    "ContainedChassis",
    "ChassisContainmentSubsystem"
]

def load_mandated_classes(destination):
    config_paths = [
        os.path.join(destination, ".pipeline", "logical-ui", "codebase_rules.json"),
        os.path.join(destination, "codebase_rules.json"),
        os.path.join(destination, "baseline_manifest.json")
    ]
    for path in config_paths:
        if os.path.isfile(path):
            try:
                with open(path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                
                classes = None
                if isinstance(data, dict):
                    if "validation_rules" in data and isinstance(data["validation_rules"], dict):
                        classes = data["validation_rules"].get("mandated_classes")
                    if classes is None:
                        classes = data.get("mandated_classes")
                
                if isinstance(classes, list):
                    if all(isinstance(c, str) for c in classes):
                        print(f"Loaded mandated classes dynamically from {path}: {classes}")
                        return classes
                    else:
                        print(f"WARNING: Invalid format for 'mandated_classes' in {path} (not all elements are strings).", file=sys.stderr)
                else:
                    print(f"WARNING: 'mandated_classes' not found or not a list in {path}.", file=sys.stderr)
            except Exception as e:
                print(f"WARNING: Failed to parse or load config {path}: {e}", file=sys.stderr)
    
    print("Using default hardcoded MANDATED_CLASSES.")
    return MANDATED_CLASSES

def main():
    parser = argparse.ArgumentParser(description="Verify a downstream project's baseline conformance.")
    parser.add_argument("platform", choices=["react", "flutter"], help="Target platform ('react' or 'flutter')")
    parser.add_argument("destination", help="Path to the downstream project directory")
    args = parser.parse_args()

    platform = args.platform
    dest = os.path.abspath(args.destination)

    if not os.path.isdir(dest):
        print(f"ERROR: Destination path '{dest}' is not a directory.", file=sys.stderr)
        sys.exit(1)

    print(f"Verifying conformance for platform '{platform}' at '{dest}'...")

    # 1. Assert baseline files exist
    if platform == "react":
        baseline_files = [
            "package.json",
            "tsconfig.json",
            "vite.config.ts",
            "index.html",
            "src/main.tsx",
            "src/App.tsx",
            "src/types.ts"
        ]
        types_file = os.path.join(dest, "src", "types.ts")
    else:  # flutter
        baseline_files = [
            "pubspec.yaml",
            "analysis_options.yaml",
            "lib/main.dart",
            "lib/domain/types.dart",
            "lib/domain/validation.dart"
        ]
        types_file = os.path.join(dest, "lib", "domain", "types.dart")

    missing_files = []
    for f in baseline_files:
        path = os.path.join(dest, f)
        if not os.path.exists(path):
            missing_files.append(f)

    if missing_files:
        print(f"ERROR: Baseline file(s) missing: {', '.join(missing_files)}", file=sys.stderr)
        sys.exit(1)

    print("Success: All baseline files exist.")

    # 2. Validate type compatibility
    if not os.path.exists(types_file):
        print(f"ERROR: Types file '{types_file}' does not exist.", file=sys.stderr)
        sys.exit(1)

    with open(types_file, "r", encoding="utf-8") as f:
        content = f.read()

    missing_classes = []
    mandated_classes = load_mandated_classes(dest)
    for cls in mandated_classes:
        if platform == "react":
            pattern = rf"\b(?:interface|class)\s+{cls}\b"
        else:
            pattern = rf"\bclass\s+{cls}\b"
            
        if not re.search(pattern, content):
            missing_classes.append(cls)

    if missing_classes:
        print(f"ERROR: Type validation failed. Mandated classes/interfaces missing in {os.path.basename(types_file)}: {', '.join(missing_classes)}", file=sys.stderr)
        sys.exit(1)

    print("Success: Type compatibility validation passed (all mandated domain classes exist).")

    # 3. Run build/test commands
    try:
        if platform == "react":
            # Check if node_modules is missing or package.json exists.
            # We want to run npm install to ensure package-lock.json/dependencies are resolved.
            node_modules_path = os.path.join(dest, "node_modules")
            if not os.path.isdir(node_modules_path):
                print("node_modules folder not found. Running 'npm install'...")
                subprocess.run(["npm", "install"], cwd=dest, check=True)
            
            print("Running 'npm run build'...")
            subprocess.run(["npm", "run", "build"], cwd=dest, check=True)
        else:  # flutter
            print("Running 'flutter pub get' to resolve dependencies...")
            subprocess.run(["flutter", "pub", "get"], cwd=dest, check=True)
            
            print("Running 'flutter analyze'...")
            subprocess.run(["flutter", "analyze"], cwd=dest, check=True)
            
            print("Running 'flutter test'...")
            subprocess.run(["flutter", "test"], cwd=dest, check=True)
    except subprocess.CalledProcessError as e:
        print(f"ERROR: Verification command failed: {e}", file=sys.stderr)
        sys.exit(1)

    print("Success: Build and test suite execution passed. Conformance gate verified.")
    sys.exit(0)

if __name__ == "__main__":
    main()
