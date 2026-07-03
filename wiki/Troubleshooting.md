<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Troubleshooting

This page collects common failures, diagnostic steps, and recovery paths for the Digital Systems Engineering Pipeline.

## General Diagnostic Protocol

For any failure:

1. Capture the exact error message, stderr, and exit code.
2. Identify the failing phase, skill, or script.
3. Check that prerequisites and configuration are correct.
4. Attempt remediation once.
5. If the failure appears to be a pipeline tooling bug, file an upstream issue.
6. Escalate to the user with full context.

## Specification Pipeline Issues

### Phase 1 fails to create Features or Epics

**Symptoms:** `gh issue create` errors, missing tracker labels, or empty issue lists.

**Checks:**
- Is `gh` authenticated? Run `gh auth status`.
- Are the tracker labels (`epic`, `feature`, `user-story`, `use-case`) bootstrapped?
- Does the functional constitution exist and is it readable?
- Are schema file paths correct?

**Recovery:**
- Re-run Phase 1 after fixing the underlying issue.
- Verify with `gh issue list --limit 1000 --state all --json number,title,state,labels`.

### Phase 2 or 3 User Stories / Use Cases are not linked to Features

**Symptoms:** Tasklists in issue bodies do not render Feature IDs.

**Checks:**
- Did Phase 1 complete successfully and create Features?
- Are the Features findable by the tracker query used by the worker?
- Is the issue tracker slow or rate-limited? Wait and retry.

**Recovery:**
- Re-run Phase 2 and/or Phase 3 after Phase 1 is verified.
- On single-agent runtimes, ensure Phase 2 runs before Phase 3.

### Reconciliation script fails

**Symptoms:** `reconcile_backlog.py` exits non-zero.

**Common causes:**
- Missing `PyYAML`.
- Invalid frontmatter in markdown files.
- Tracker CLI authentication expired.
- Network issues querying the tracker.

**Recovery:**
- Install dependencies: `pip install -r requirements.txt`.
- Validate YAML frontmatter in all `docs/` markdown files.
- Re-authenticate: `gh auth login`.
- Re-run the script.

### UML coverage linter reports less than 100%

**Symptoms:** `verify_model_coverage.py` exits non-zero.

**Common causes:**
- Schema elements missing from class diagrams.
- Mermaid syntax errors in diagram blocks.
- Cross-view inconsistency (e.g., sequence diagram references undefined class).
- Incorrect UML arrow directionality.

**Recovery:**
- Review the linter output for the specific missing elements.
- Add the missing classes/attributes to the Mermaid class diagram.
- Fix Mermaid syntax errors.
- Ensure every element in sequence/use-case diagrams is defined in the structural models.

## Feature Implementation Issues

### The Grill plan is rejected

**Symptoms:** User requests changes or refuses to approve the implementation plan.

**Recovery:**
- Capture the feedback.
- Revise the implementation plan.
- Re-present for approval.
- Do not start coding until the plan is approved.

### TDD cycle fails

**Symptoms:** Test does not fail when expected, or code does not make it pass.

**Checks:**
- Is the test actually asserting the new behavior?
- Is the test running against the right file/module?
- Is the code path exercised by the test?

**Recovery:**
- If the test passes before implementation, rewrite the test to truly fail.
- If the code does not pass, use systematic debugging: Reproduce, Diagnose, Fix, Verify.
- Delete any code written before its corresponding test and re-implement after the test.

### Two-stage review fails

**Symptoms:** Spec compliance or code quality review finds issues.

**Recovery:**
- Do not proceed to Stage 2 until Stage 1 passes.
- Address the implementer's fixes.
- Re-run the review.
- Document any deviations from the plan in the task tracking file.

### Epic is not closed automatically

**Symptoms:** Feature is closed but Epic remains open.

**Checks:**
- Are all features in the Epic checklist marked `[x]`?
- Did the local Epic markdown get committed and pushed?
- Did the Epic issue body get updated on the tracker?

**Recovery:**
- Manually check off the feature in the Epic markdown.
- Commit and push the Epic file.
- Update and close the Epic issue on the tracker.

## Configuration Issues

### Constitution not found

**Symptoms:** Agent reports missing `.pipeline/constitution.md`.

**Recovery:**
- Use the `project-constitution` skill to create one.
- Ensure the file is committed and readable.

### Missing implementation profile

**Symptoms:** Agent halts because `.pipeline/profiles/<platform>.md` does not exist.

**Recovery:**
- Use the `project-constitution` skill to create the profile.
- Ensure the platform identifier matches the one requested.

### Tracker CLI not authenticated

**Symptoms:** `gh` commands fail or return 401/403.

**Recovery:**
- Run `gh auth login`.
- Verify with `gh issue list`.

## Environment Issues

### Firestore emulator not running

**Symptoms:** Persistence integration tests fail to connect.

**Recovery:**
```bash
npx firebase-tools emulators:start --only firestore
```

### Python scripts fail

**Symptoms:** `ModuleNotFoundError` or `PyYAML` errors.

**Recovery:**
```bash
pip install -r requirements.txt
```

## Upstream Bug Reporting

If a pipeline tooling bug is suspected:

1. Locate the latest diagnostic payload:
   ```bash
   ls .pipeline/diagnostics/repro_payload_*.json
   ```
2. Create the upstream issue:
   ```bash
   gh issue create --repo gintatkinson/digital-pipeline-repo \
     --title "Tooling Bug: [Command] failed" \
     --body-file [payload_path] \
     --label "bug"
   ```
3. Escalate to the user with the issue URL.

## Escalation Checklist

Escalate to the user when:

- A validation gate cannot be satisfied.
- The plan is wrong and must be revised at The Grill.
- A tooling bug is suspected and an upstream issue is filed.
- A rule conflicts with a proposed action.
- Manual verification is required but cannot be automated.
