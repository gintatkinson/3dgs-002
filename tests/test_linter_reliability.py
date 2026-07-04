import os
import sys
import json
import shutil
import subprocess
import pytest
from unittest.mock import patch, MagicMock

from parity_auditor.core.workspace import WorkspaceRepository
from parity_auditor.validators.schema_mapping_validator import SchemaMappingValidator
from parity_auditor.validators.profile_scoping_validator import ProfileScopingValidator
from parity_auditor.validators.test_completeness_validator import TestCompletenessValidator
from parity_auditor.cli import main

@pytest.fixture
def base_config():
    return {
        "meta": {
            "version": "1.0.0",
            "description": "Minimal configuration for testing",
            "upstream_repository": "gintatkinson/digital-pipeline-repo"
        },
        "backlog_directories": {
            "epics": "docs/epics",
            "features": "docs/features",
            "user_stories": "docs/user-stories",
            "use_cases": "docs/use-cases",
            "schemas": "schema"
        },
        "target_directories": {
            "flutter": "app_flutter"
        },
        "flutter_rules": {
            "file_extensions": [".dart"],
            "exclusions": ["build", ".git"],
            "ui_directories": ["widgets", "screens"]
        },
        "validation_rules": {
            "schema_exclude_keywords": ["description", "reference"],
            "schema_patterns": {
                ".yang": {
                    "name_regex": "\\bmodule\\s+([a-zA-Z0-9_\\-]+)",
                    "patterns": [
                        "\\btypedef\\s+([a-zA-Z0-9_\\-]+)",
                        "\\bleaf\\s+([a-zA-Z0-9_\\-]+)",
                        "\\bcontainer\\s+([a-zA-Z0-9_\\-]+)",
                        "\\blist\\s+([a-zA-Z0-9_\\-]+)",
                        "\\brpc\\s+([a-zA-Z0-9_\\-]+)",
                        "\\baction\\s+([a-zA-Z0-9_\\-]+)"
                    ]
                }
            },
            "alternative_schema_extensions": []
        }
    }

def setup_workspace(tmp_path, config, schemas=None, flutter_files=None):
    ws_dir = tmp_path / "test_workspace"
    os.makedirs(ws_dir, exist_ok=True)
    
    # Write codebase_rules.json
    rules_dir = ws_dir / ".pipeline" / "logical-ui"
    os.makedirs(rules_dir, exist_ok=True)
    with open(rules_dir / "codebase_rules.json", "w", encoding="utf-8") as f:
        json.dump(config, f)
        
    # Write schemas
    schema_dir = ws_dir / "schema"
    os.makedirs(schema_dir, exist_ok=True)
    if schemas:
        for name, content in schemas.items():
            with open(schema_dir / name, "w", encoding="utf-8") as f:
                f.write(content)
                
    # Write Flutter codebase files
    flutter_dir = ws_dir / "app_flutter"
    os.makedirs(flutter_dir, exist_ok=True)
    if flutter_files:
        for rel_path, content in flutter_files.items():
            filepath = flutter_dir / rel_path
            os.makedirs(os.path.dirname(filepath), exist_ok=True)
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(content)
                
    return ws_dir

def test_comment_only_bypass(tmp_path, base_config):
    # 1. Define a feature spec with class 'Location' in schema
    schemas = {
        "location.yang": """
        module location {
            container Location {
                leaf id { type string; }
            }
        }
        """
    }
    # 2. Mock codebase containing only a comment in Flutter location
    flutter_files = {
        "lib/domain/Location.dart": "// Location class info"
    }
    
    ws_dir = setup_workspace(tmp_path, base_config, schemas=schemas, flutter_files=flutter_files)
    repo = WorkspaceRepository(str(ws_dir))
    
    validator = SchemaMappingValidator()
    errors = validator.validate(repo)
    
    # Assert that validator fails and flags Location as missing
    assert any("Location" in err for err in errors), f"Expected Location to be flagged as missing, but got errors: {errors}"

def test_unrelated_variable_bypass(tmp_path, base_config):
    # 1. Define a spec with method 'increment' in schema
    schemas = {
        "math.yang": """
        module math {
            rpc increment {
                input { leaf value { type int32; } }
            }
        }
        """
    }
    # 2. Codebase file containing a variable in Flutter location
    flutter_files = {
        "lib/domain/MathController.dart": "int increment = 5;"
    }
    
    ws_dir = setup_workspace(tmp_path, base_config, schemas=schemas, flutter_files=flutter_files)
    repo = WorkspaceRepository(str(ws_dir))
    
    validator = SchemaMappingValidator()
    errors = validator.validate(repo)
    
    # Assert that validator fails
    assert any("increment" in err for err in errors), f"Expected increment to be flagged as missing/invalid, but got errors: {errors}"

def test_empty_directory_bypass(tmp_path, base_config):
    # Empty codebase directory
    ws_dir = setup_workspace(tmp_path, base_config)
    repo = WorkspaceRepository(str(ws_dir))
    
    schema_mapping_validator = SchemaMappingValidator()
    profile_scoping_validator = ProfileScopingValidator()
    
    # Assert that both fail rather than returning success
    sm_errors = schema_mapping_validator.validate(repo)
    ps_errors = profile_scoping_validator.validate(repo)
    
    assert len(sm_errors) > 0, "SchemaMappingValidator should fail for empty codebase"
    assert len(ps_errors) > 0, "ProfileScopingValidator should fail for empty codebase"

def test_missing_spec(tmp_path, base_config):
    # Setup workspace with open issue #42 but no spec file locally
    ws_dir = setup_workspace(tmp_path, base_config)
    
    # Create empty docs/features/ directory
    os.makedirs(ws_dir / "docs" / "features", exist_ok=True)
    
    # Mock gh CLI response to return open issue 42 with label 'feature'
    mock_process = MagicMock(spec=subprocess.CompletedProcess)
    mock_process.returncode = 0
    mock_process.stdout = json.dumps([
        {"number": 42, "title": "Implement authentication"}
    ])
    mock_process.stderr = ""
    
    old_cwd = os.getcwd()
    os.chdir(ws_dir)
    old_argv = sys.argv
    sys.argv = ["parity-auditor", "--spec-only"]
    
    try:
        with patch("subprocess.run", return_value=mock_process) as mock_run:
            with pytest.raises(SystemExit) as exc_info:
                main()
            assert exc_info.value.code != 0
            
            # Verify the command was run
            mock_run.assert_called_once()
            args, kwargs = mock_run.call_args
            assert "gh" in args[0]
            assert "issue" in args[0]
            assert "list" in args[0]
    finally:
        sys.argv = old_argv
        os.chdir(old_cwd)
