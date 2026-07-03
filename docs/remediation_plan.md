# Master Remediation Plan: Root Workspace Contamination Cleanup

This document outlines the master remediation plan to resolve root-level workspace contamination on the `main` branch of the `digital-pipeline-repo`. It details the problem, root causes, impacts, execution-level commands to clean up the workspace, and governance guardrails to prevent future occurrences.

---

## 1. Problem Enumeration

The `main` branch of the repository was contaminated with Flutter project files and directories directly at the root workspace level. The following files and directories were incorrectly created or committed at the root:

### Contaminated Directories (Should Reside in `app_flutter/`)
- `lib/` — Contains Flutter application source code.
- `test/` — Contains Flutter unit and widget tests.
- `linux/` — Linux platform build configuration.
- `macos/` — macOS platform build configuration.
- `web/` — Web platform build configuration.
- `integration_test/` — Integration tests for Flutter.
- `build/` (e.g., `build/ios/...`) — Local/committed Flutter build outputs.

### Contaminated Files (Should Reside in `app_flutter/` or specific subfolders)
- `pubspec.yaml` — Flutter package configuration.
- `pubspec.lock` — Flutter locked dependencies.
- `analysis_options.yaml` — Flutter static analysis rules.
- `.metadata` — Flutter project metadata.
- `firebase.json` — Root-level Firebase configuration (conflicting with clean hosting/database setup).
- `firestore.rules` — Firestore security rules placed at root.
- `firestore-debug.log` — Firebase CLI local emulator debug log.
- `implementation_plan.md` — Project-specific implementation plan written directly to the root.

### Transient/Generated Local Pollution (Untracked/Generated at Root)
- `.dart_tool/` — Dart tool cache and package mapping.
- `.flutter-plugins` — Flutter plugin mapping file.
- `.flutter-plugins-dependencies` — Flutter plugin dependencies metadata.
- `build/` (generated during local flutter run/build tasks at the root).

---

## 2. Root-Cause Analysis

The root workspace contamination occurred due to three main process and engineering gaps:

1. **Failure of Path Constraints**:
   - The project's rules in `.agents/AGENTS.md` lacked explicit constraints preventing the creation or modification of files at the root level of the workspace.
   - Without direct folder-scoping limits, agents could read and write arbitrary files anywhere in the repository.

2. **Direct Root-Level Command Execution**:
   - When bootstrapping the Flutter baseline project, the executing agent ran setup commands (such as `flutter create .`) directly within the workspace root `/Users/perkunas/jail/digital-pipeline-repo` rather than navigating to the designated subdirectory `/Users/perkunas/jail/digital-pipeline-repo/app_flutter`.
   - The agent failed to verify the current working directory (`Cwd`) before executing command-line generators.

3. **Lack of Automated Verification and Check Gates**:
   - The coordinator agent accepted the subagent's changes and merged them without verifying structural layout cleanliness.
   - Because the test suite passed locally in the root directory context, the agent assumed the implementation was successful, ignoring the architectural violations.
   - No automated linting or CI/CD gate existed to reject PRs containing root-level files like `pubspec.yaml` or `lib/`.

---

## 3. Impact Assessment

The contamination of the root workspace has several critical negative consequences:

- **Tooling and IDE Conflicts**:
  - IDEs (e.g., VS Code, Android Studio) detect `pubspec.yaml` at the root and treat the entire repository as a single Flutter project. This leads to duplicate analysis servers running, broken imports, and severe IDE performance degradation.
- **Documentation Overwrite and Drift**:
  - The root `README.md` (which defines the digital pipeline setup, rules, and architecture instructions) was overwritten with generic Flutter template instructions, leading to a critical loss of developer onboarding and governance documentation.
- **Blocking Downstream Integration**:
  - Verification scripts (like `verify_downstream_baseline.py`) and deployment pipelines are blocked because they expect structural separation between `app_flutter`, `web_react`, and other platform components. Commingled root files make it impossible to isolate builds.

---

## 4. Execution-Level Sandbox Remedy

Follow these step-by-step commands in a sandboxed terminal environment to clean up the contaminated `main` branch, restore the original files, and update the workspace.

### Step 1: Quarantine the Workspace
Save any uncommitted local work (including untracked files) to avoid accidental data loss:
```bash
git stash -u
```

### Step 2: Clone a Pristine Copy (Optional Reference)
Clone the repository to a temporary location to verify original files or retrieve clean versions:
```bash
git clone https://github.com/gintatkinson/digital-pipeline-repo.git /tmp/pristine-pipeline-repo
```

### Step 3: Clean Up the Main Branch
Checkout the contaminated branch, remove the incorrect root directories and files from git tracking:
```bash
# Switch to main branch
git checkout main

# Remove contaminated directories
git rm -r lib test linux macos web integration_test build/ios

# Remove contaminated configuration files
git rm pubspec.yaml pubspec.lock analysis_options.yaml .metadata firebase.json firestore.rules firestore-debug.log implementation_plan.md
```

### Step 4: Restore Original Files
Restore the clean version of `README.md` and standard project configuration from the `restore-june30` branch:
```bash
git checkout restore-june30 -- README.md firebase.json firestore.rules
```

### Step 5: Commit and Push Clean State
Commit the clean, restored repository layout and push the updates:
```bash
git commit -m "chore: remediate root workspace contamination and restore original configuration"
git push origin main
```

### Step 6: Clean Up Local Untracked Garbage
Ensure no generated files remain in the root directory:
```bash
rm -rf .dart_tool/ .flutter-plugins .flutter-plugins-dependencies build/
```

---

## 5. Governance Guardrails

To prevent future root-level contamination, append the following rules to the project's `.agents/AGENTS.md` file:

```markdown
## Strict Root-Level File Locks & Directory Scoping
- **Root Directory Lock**: Agents are strictly forbidden from creating, modifying, or deleting any files or directories at the repository root level (`/Users/perkunas/jail/digital-pipeline-repo/`) directly, except for the following pre-approved global files:
  - `.agents/AGENTS.md`
  - `.gitignore`
  - `LICENSE`
  - `tessl.json`
- **Application Directory Scoping**: All application-specific codebase modifications, testing, and dependency files must reside exclusively within their designated subdirectories:
  - Flutter Application: `app_flutter/` (e.g., `app_flutter/lib/`, `app_flutter/test/`, `app_flutter/pubspec.yaml`)
  - React Web Application: `web_react/` (e.g., `web_react/src/`, `web_react/package.json`)
  - Integration/Test Harness: `app_test_harness/` or `tests/`
- **Command Execution Cwd Validation**: Prior to running any CLI tool (such as `flutter`, `npm`, `firebase`, `python3`), the agent MUST explicitly set the `Cwd` to the correct sub-directory. Running project initialization or package management commands (e.g. `flutter create`, `npm install`, `flutter pub get`) in the root directory is strictly prohibited.
- **Repository Cleanliness Check**: Before completing any task, the agent must verify that no untracked files or directories have been created in the repository root by running `git status` and cleaning up any transient directories (such as `.dart_tool/` or `build/` generated at the root).
```
