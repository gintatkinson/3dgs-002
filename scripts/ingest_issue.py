#!/usr/bin/env python3
import os
import sys
import json
import re

def main():
    body = os.environ.get("ISSUE_BODY", "")
    issue_number = os.environ.get("ISSUE_NUMBER", "repro")
    
    if len(sys.argv) > 1:
        filepath = sys.argv[1]
        if os.path.exists(filepath):
            with open(filepath, "r", encoding="utf-8") as f:
                body = f.read()
        else:
            body = sys.argv[1]
            
    if len(sys.argv) > 2:
        issue_number = sys.argv[2]
        
    if not body:
        print("Error: No issue body provided via ISSUE_BODY env var or argument.", file=sys.stderr)
        sys.exit(1)
        
    body_str = body.strip()
    
    # Extract JSON from markdown code block if present
    json_match = re.search(r'```json\s*(.*?)\s*```', body_str, re.DOTALL)
    if json_match:
        json_str = json_match.group(1)
    else:
        curly_match = re.search(r'(\{.*\})', body_str, re.DOTALL)
        if curly_match:
            json_str = curly_match.group(1)
        else:
            json_str = body_str
            
    try:
        payload = json.loads(json_str)
    except Exception as e:
        print(f"Warning: Error parsing JSON payload: {e}")
        print(f"Payload was: {json_str[:500]}...")
        sys.exit(0)
        
    if "reproduction_case" not in payload:
        print("Warning: Missing 'reproduction_case' key in payload.")
        sys.exit(0)
        
    repro = payload["reproduction_case"]
    if not isinstance(repro, dict):
        print("Warning: 'reproduction_case' is not a dictionary.")
        sys.exit(0)
        
    if "target_file" not in repro:
        print("Warning: Missing 'target_file' key in reproduction_case.")
        sys.exit(0)
        
    if "snippet_content" not in repro:
        print("Warning: Missing 'snippet_content' key in reproduction_case.")
        sys.exit(0)
        
    target_file = repro["target_file"]
    content = repro["snippet_content"]
    
    if not target_file or not content:
        print("Warning: 'target_file' or 'snippet_content' is empty in reproduction_case.")
        sys.exit(0)
        
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.abspath(os.path.join(script_dir, ".."))
    
    rel_target = target_file.lstrip("/")
    dest_path = os.path.join(project_root, "tests", "repro_cases", str(issue_number), rel_target)
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    
    with open(dest_path, "w", encoding="utf-8") as f:
        f.write(content)
        
    print(f"Ingested reproduction case from issue {issue_number} to {dest_path}")

if __name__ == "__main__":
    main()
