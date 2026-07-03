# Implementation Plan - Complete Removal of React Application

This plan details the steps to completely remove the React application (`web_react/`) from the workspace and clean up all associated references, validation rules, configurations, design solutions, audit scripts, and tests.

## Proposed Changes

### 1. Delete the React Application Directory
- **Action**: Delete the React source codebase directory.
  - `[DELETE] web_react/`

### 2. Update Workspace Agent Rules
- **File**: [`/Users/perkunas/jail/3dgs-002/.agents/AGENTS.md`](file:///Users/perkunas/jail/3dgs-002/.agents/AGENTS.md)
- **Action**: Remove the rule enforcing `web_react/` location constraints.
- **Changes**:
  - Remove line 59: ` - All source code, assets, configurations, and tests for the React application MUST reside exclusively under web_react/.`

### 3. Update Codebase Rules Schema
- **File**: [`/Users/perkunas/jail/3dgs-002/.pipeline/logical-ui/codebase_rules.json`](file:///Users/perkunas/jail/3dgs-002/.pipeline/logical-ui/codebase_rules.json)
- **Action**: Remove the React target directory config and the entire `react_rules` block.
- **Changes**:
  - In `target_directories`, delete: `"react": "web_react",` (line 51)
  - Delete `react_rules` object completely (lines 54 to 70).

### 4. Clean Up Solution Walkthrough for Feature 11
- **File**: [`/Users/perkunas/jail/3dgs-002/docs/designs/feat-11-solution.md`](file:///Users/perkunas/jail/3dgs-002/docs/designs/feat-11-solution.md)
- **Action**: Remove React-specific component descriptions, Code Realization Table entries mapping React components, and React build/compilation verification steps.
- **Changes**:
  - Remove "React Implementation" description section (lines 7 to 13).
  - Remove rows from the Code Realization Table that map elements to React (`web_react`) code (e.g., breadcrumbs, contextual-panel, topology-map, layout, HierarchyTreeSelector, ResizableSplitter, TabbedContainer, TableView).
  - Remove the "React Type Safety" validation step from section 3 (lines 43 to 47).

### 5. Clean Up Solution Walkthrough for Feature 44
- **File**: [`/Users/perkunas/jail/3dgs-002/docs/designs/feat-44-solution.md`](file:///Users/perkunas/jail/3dgs-002/docs/designs/feat-44-solution.md)
- **Action**: Remove references to React within downstream seeding descriptions, class constraints, Code Realization mapping, and React verification results.
- **Changes**:
  - Update overview and script usage to reference Flutter exclusively instead of React/Flutter.
  - Remove React files (`package.json`, `tsconfig.json`, `vite.config.ts`, `src/types.ts`) from baseline file checklists.
  - Remove React mapping rows from the Code Realization Table.
  - Delete the entire "React Baseline Verification" result segment (Section 5.1).

### 6. Clean Up Remediation Plan
- **File**: [`/Users/perkunas/jail/3dgs-002/docs/remediation_plan.md`](file:///Users/perkunas/jail/3dgs-002/docs/remediation_plan.md)
- **Action**: Remove React-specific references from directory separation descriptions and governance rules.
- **Changes**:
  - Remove mention of `web_react` and downstream separation rules referencing React (line 66).
  - Remove the scoping rule listing React Web Application in `web_react/` (line 133).

### 7. Clean Up Persistence Use Case
- **File**: [`/Users/perkunas/jail/3dgs-002/docs/use-cases/uc-03-remote-firestore-cloud.md`](file:///Users/perkunas/jail/3dgs-002/docs/use-cases/uc-03-remote-firestore-cloud.md)
- **Action**: Remove references to the React web console configuration, React persistence mapping, and React deployment profiles.
- **Changes**:
  - Remove React references in parent epic description (line 12).
  - Delete the entire "Operational Context" section (Section 7, lines 86 to 94) which details the `web_react` deployment configuration.

### 8. Update Spec Implementation Auditor Skill
- **File**: [`/Users/perkunas/jail/3dgs-002/skills/spec-implementation-auditor/SKILL.md`](file:///Users/perkunas/jail/3dgs-002/skills/spec-implementation-auditor/SKILL.md)
- **Action**: Remove React directory scanning path from Step 2 of the auditor protocol.
- **Changes**:
  - Modify step 2 directory checklist to only search Flutter (`lib/`) and Python (`scripts/`), removing `React (web_react/src/)`.

### 9. Update Parity Auditor Models
- **File**: [`/Users/perkunas/jail/3dgs-002/skills/spec-orchestrator/parity_auditor/src/parity_auditor/core/models.py`](file:///Users/perkunas/jail/3dgs-002/skills/spec-orchestrator/parity_auditor/src/parity_auditor/core/models.py)
- **Action**: Remove `ReactRules` data class, remove `react` field from `TargetDirectories`, and remove the corresponding parser properties from `CodebaseRules`.
- **Changes**:
  - Remove `react` attribute from `TargetDirectories` class (line 27).
  - Remove `ReactRules` data class definition (lines 30 to 46).
  - Remove `react_rules` attribute from `CodebaseRules` class (line 132).
  - Remove `react_rules` initialization and extraction logic from `load_from_dict` (lines 148-149, 168).

### 10. Update Linter Reliability Tests
- **File**: [`/Users/perkunas/jail/3dgs-002/tests/test_linter_reliability.py`](file:///Users/perkunas/jail/3dgs-002/tests/test_linter_reliability.py)
- **Action**: Adapt base configurations and linter bypass test scenarios to target the remaining Flutter platform rather than React.
- **Changes**:
  - Remove `react` and `react_rules` from the `base_config` test fixture (lines 31, 34-38).
  - Remove `react_files` processing logic from the `setup_workspace` helper method.
  - Refactor `test_comment_only_bypass` and `test_unrelated_variable_bypass` to write mock file contents into `lib/domain/Location.dart` and `lib/domain/MathController.dart` under the `app_flutter` target directories, instead of components inside `web_react/`.

## Verification Plan

### Step 1: Execute Linter Tests
- Verify that `parity_auditor` tests execute successfully with the updated schemas and adapted test configs:
  `pytest tests/test_linter_reliability.py`

### Step 2: Validate Flutter Codebase
- Verify that the Flutter application compiles and passes validation:
  `cd app_flutter && flutter analyze && flutter test`

### Step 3: Run Model Coverage Checks
- Run the coverage verification command to confirm that the removed targets do not cause validation blockages:
  `python3 skills/spec-orchestrator/scripts/verify_model_coverage.py`
