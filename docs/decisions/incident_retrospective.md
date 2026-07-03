# Incident Retrospective: Workspace Pollution & Failed SSH Fix

## 1. Context & Background
During the feature implementation phase of the digital systems engineering pipeline, automated compliance testing was required to verify the UML linter, alternate flows validation, and codebase bypass loophole checks. 

## 2. The Pollution (The Damage)
- **Mock Workspace Directory:** The agent created a mock target project folder (`test_project/`) inside the main repository containing sample schemas, epics, features, user stories, use cases, and code targets (React and Flutter mock files), along with a test runner (`run_tests.py`).
- **Production Code Contamination:** Because the linter scanned the entire repository workspace, the agent hardcoded `"test_project"` into the exclusions list in `skills/spec-orchestrator/parity_auditor/src/parity_auditor/validators/codebase.py`. This created a dependency in production validation code on an ephemeral mock folder.
- **Documentation Contamination:** The agent documented the mock test execution command `python3 test_project/run_tests.py` inside core architectural and decision documentation files:
  - `docs/feat-decoupled-persistence-layout-engine-design.md`
  - `docs/designs/feat-usecase-alternate-flows-solution.md`
- **Mock Use Case Leftover:** A mock Use Case file `docs/use-cases/uc-03-handle-location-expiration.md` remained in the repository, referencing the non-existent `ietf-geo-location.yang` schema and dummy stories.

This pollution carried high risk: downstream agents running in this workspace would read these mock specifications and files, leading to pipeline confusion and board sync issues.

## 3. The Faulty Fix Attempt
When cleaning up the mock folder locally, the agent attempted to push the changes. The push failed over HTTPS with the error:
`fatal: could not read Username for 'https://github.com': Device not configured`

Instead of diagnosing the blocker, the agent assumed the macOS Keychain credential helper was fundamentally blocked by the sandbox and switched the remote URL to SSH (`git@github.com:...`). Because SSH keys were not loaded in the active agent socket (`The agent has no identities.`), this failed with `Permission denied (publickey)`.

## 4. Root Cause & Real Resolution
- **Diagnosis:** Running `gh auth status` and `ssh-add -l` revealed that the SSH agent had no identities, but the macOS Keychain did have valid HTTPS credentials. The HTTPS push was actually being blocked because the agent process environment had an invalid `GITHUB_TOKEN` set, which Git was trying to use instead of the keychain helper.
- **Resolution:** Running the Git push commands with the invalid `GITHUB_TOKEN` environment variable explicitly unset (`env -u GITHUB_TOKEN`) forced Git to use the macOS keychain helper, successfully pushing all commits and synchronizing the remote repository.

## 5. Preventative Rules Enforced
To prevent this type of contamination from recurring:
1. **Forbidden Test Workspace Creation:** Added a rule to `.agents/AGENTS.md` strictly forbidding the creation of mock test projects, directories, or runner files in the workspace. All testing validation must run outside the workspace.
2. **Remote Synchronization Mandate:** Added a rule to `.agents/AGENTS.md` requiring that all changes must be pushed to and verified on the remote tracking branch (ensuring `git diff origin/<branch>` is empty) before a task can be marked complete.
