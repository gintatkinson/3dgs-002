import os
import sys
import json
import shutil
import pytest
from parity_auditor.cli import main

def test_repro_cases(tmp_path):
    repro_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "repro_cases"))
    if not os.path.exists(repro_dir):
        pytest.skip("No reproduction cases directory found")
        
    issues = [d for d in os.listdir(repro_dir) if os.path.isdir(os.path.join(repro_dir, d))]
    if not issues:
        pytest.skip("No issue reproduction cases found")
        
    orig_rules_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".pipeline", "logical-ui", "codebase_rules.json"))
    with open(orig_rules_path, "r", encoding="utf-8") as f:
        rules_data = json.load(f)
        
    for issue in issues:
        issue_src_dir = os.path.join(repro_dir, issue)
        ws_dir = tmp_path / issue
        os.makedirs(ws_dir, exist_ok=True)
        
        shutil.copytree(issue_src_dir, ws_dir, dirs_exist_ok=True)
        
        os.makedirs(ws_dir / ".pipeline" / "logical-ui", exist_ok=True)
        with open(ws_dir / ".pipeline" / "logical-ui" / "codebase_rules.json", "w", encoding="utf-8") as f:
            json.dump(rules_data, f)
            
        old_cwd = os.getcwd()
        os.chdir(ws_dir)
        
        old_argv = sys.argv
        sys.argv = ["parity-auditor", "--spec-only"]
        
        try:
            main()
        except SystemExit as e:
            assert e.code == 0, f"Reproduction case for issue {issue} failed validation with exit code {e.code}"
        finally:
            sys.argv = old_argv
            os.chdir(old_cwd)
