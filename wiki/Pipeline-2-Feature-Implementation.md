<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Pipeline 2: Feature Implementation

Pipeline 2 implements features from the backlog produced by Pipeline 1. It uses a strict, subagent-driven, TDD-disciplined execution model with human approval gates, micro-task decomposition, and automated Epic closure.

## Purpose

- Deliver backlog features one at a time with full traceability.
- Enforce RED-GREEN-REFACTOR for every micro-task.
- Prevent context drift, false completion, and confirmation bias.
- Produce cumulative solution walkthroughs and automatically close tracker issues.

## Core Mandates (14)

| # | Mandate | Purpose |
|---|---|---|
| 1 | Serial Execution | One feature at a time, fully closed before the next |
| 2 | The Grill Approval | Interactive design review before any source code modification |
| 3 | Traceability | Closing comments link to the committed solution walkthrough |
| 4 | Agentic Epic Closure | Auto-close Epics when all constituent features are complete |
| 5 | Verification Isolation | Use only approved testing frameworks; no ad-hoc browser automation |
| 6 | Issue Tracker as Source of Truth | Query the tracker CLI; never trust local state |
| 7 | Cumulative Walkthroughs | Append and merge; never destructively overwrite |
| 8 | Validation Isolation | Separate validator subagent or strict self-audit fallback |
| 9 | TDD (RED-GREEN-REFACTOR) | Failing test before code, always |
| 10 | Micro-Task Decomposition | 2-5 minute tasks, each with a driving test |
| 11 | Subagent-Driven Development | Fresh isolated context per micro-task |
| 12 | Two-Stage Review | Spec compliance first, then code quality |
| 13 | Verification-Before-Completion | Raw proof required; no assertions |
| 14 | Inter-Task Code Review | Diff against plan and log deviations |

## The Six Steps

### Step 1: Backlog and Dependency Mapping

1. Read the functional constitution (`.pipeline/constitution.md`).
2. Read the implementation profile for the target platform (`.pipeline/profiles/<platform>.md`).
3. Analyze `docs/epics/` and `docs/features/` to determine dependencies.
4. Map the backlog queue in dependency order (base layers first).
5. Create a local tracking file (e.g., `task.md`).

### Step 1.5: Tech Stack Research (Optional)

If the feature involves unfamiliar or rapidly evolving frameworks:

1. Identify the specific APIs, libraries, or patterns required.
2. Check installed/pinned dependency versions.
3. Document findings in `research.md` on the feature branch.
4. Feed `research.md` into The Grill review.

Skip this step if the feature uses well-established patterns already documented in the codebase.

### Step 2: Checkout and Plan Review (The Grill)

1. Check out a dedicated feature branch from the default branch.
2. Apply platform scoping from the implementation profile to translate functional specs into concrete design decisions.
3. Create or update `implementation_plan.md` covering the full vertical slice:
   - Architectural layers
   - Layout engine alignment (container queries, resizable splitters, SVG icon limits)
   - Emulator integration for persistence tests
   - TDD test plan with failing tests specified before implementation
   - Verification plan
4. Decompose the plan into micro-tasks (2-5 minutes each). Each micro-task specifies target files, expected changes, a driving test, and a verification step.
5. Present the plan to the user and wait for explicit approval.

### Step 3: Execution and Build (Subagent-Driven TDD Vertical Slice)

The coordinator reads the approved plan once, extracts all micro-tasks, and dispatches a fresh implementer subagent per task.

#### Pre-Execution

- Do not assume previous turns implemented code correctly.
- Explicitly open and inspect source files.
- Extract every micro-task with its full text, target files, driving test, and verification step.

#### Per-Task Dispatch Loop

**A. Dispatch Implementer (Fresh Context)**

The implementer receives only:
- The micro-task text
- Relevant file contents
- Project conventions (TDD, typing, navigation rules)
- The driving test specification

The coordinator must append the keyword `PROCEED` to the end of the subagent prompt to authorize tool modifications.

**B. Implementer Executes TDD Cycle**

1. **RED:** Write the failing test. Run it. Confirm it fails.
2. **GREEN:** Write minimal code to pass the test. Run it. Confirm it passes.
3. **REFACTOR:** Clean up while keeping tests green. Run tests again.
4. **COMMIT:** Commit the passing micro-task.
5. **SELF-REVIEW:** Review own changes before handing back.

**C. Handle Implementer Status**

- `DONE` — proceed to two-stage review.
- `DONE_WITH_CONCERNS` — read concerns; resolve correctness issues before review.
- `NEEDS_CONTEXT` — provide missing context and re-dispatch.
- `BLOCKED` — assess whether the blocker is context, complexity, or a plan error; escalate to The Grill if the plan is wrong.

#### Two-Stage Review Gate

**Stage 1: Spec Compliance Review**
- Does the code match the approved plan?
- Does it comply with the RFC/spec requirements?
- Is anything missing or extra?
- Are persistence transactions validated against a running emulator (no stubs)?
- Does database SDK coupling leak into UI/presentation components?
- Does layout engine compliance pass (container queries, resizable splitters, SVG icon limits)?

**Stage 2: Code Quality Review**
- Is the code well-structured and idiomatic?
- Are types strict and correct?
- Are tests meaningful (not smoke-only)?
- Does the code follow project conventions?

Both reviews must pass before proceeding to the next micro-task.

#### Systematic Debugging

If a test fails unexpectedly:

1. **Reproduce:** Isolate the failure. Run the single failing test. Record exact output.
2. **Diagnose:** Trace the root cause from the stack trace; do not guess.
3. **Fix:** Apply the minimal upstream fix; prefer single-line changes.
4. **Verify:** Run the full test suite to confirm no regressions.

### Step 4: Verification and Testing

1. Write explicit assertions that query return values, object states, or output trees.
2. Run local tests or build checks using the platform profile's commands.
3. Paste raw test/build output as evidence.
4. Provide precise, step-by-step human manual testing instructions.
5. Perform independent validation via a separate validator subagent (or strict self-audit fallback).

### Step 5: Release and Closure

1. Merge the feature branch into the default branch.
2. Create or update the cumulative solution walkthrough:
   - File: `docs/designs/feat-<Issue_Number>-solution.md`
   - Must include a **Code Realization Table** mapping features/attributes to source files, classes, methods, and functions.
   - Must append/merge; never overwrite prior sections.
3. Commit and push the solution document.
4. Close the feature issue on the tracker with a comment linking to the committed walkthrough.
5. Update the local parent Epic checklist:
   - Mark the completed feature as `[x]`.
   - Commit and push the updated Epic file.

### Step 6: Agentic Epic Closure

1. Inspect the local Epic checklist.
2. If all features are checked off:
   - Update the Epic issue body on the tracker.
   - Close the Epic issue with a completion comment.
3. Delete the feature branch locally and remotely.

## Data Flow Slicing Order

Unless the platform profile specifies otherwise, implement vertical slices in this order:

1. **Persistence Layer:** Abstract repository interfaces, concrete transport adapters, local emulator integration.
2. **Transformation Layer:** Clean domain models, types, validation, hooks, parsers.
3. **Interface Layer:** Logical components, container queries, resizable layout splitters, SVG outline icons.

## Verification-Before-Completion

Allowed proof:
- Raw test output
- Raw build output
- Explicit file-content verification

Forbidden proof:
- "It works" without evidence
- "Tests pass" without pasted output
- Summaries of expected behavior
- Assumptions from prior steps

## Error Recovery

If a tool command fails during implementation:

1. Do not proceed.
2. Log the exact error (stderr, exit code).
3. If the failure appears to be a pipeline tooling bug, file an upstream issue using the latest diagnostic payload at `.pipeline/diagnostics/repro_payload_[timestamp].json`:
   ```bash
   gh issue create --repo gintatkinson/digital-pipeline-repo \
     --title "Tooling Bug: [Command] failed" \
     --body-file [payload_path] \
     --label "bug"
   ```
4. Escalate to the user with the issue URL and full context.

## Typical Prompt

```
Adopt the feature-driven implementation skill. I want to implement Feature [#Issue Number] targeting platform [react | flutter | dotnet | etc.].

Execute the full delivery workflow with TDD execution discipline:
1. Map dependencies from the backlog directory.
2. Draft an implementation plan covering the full vertical slice.
3. Decompose into micro-tasks (2-5 min each, with a driving test per task).
4. Present the plan for approval (The Grill).
5. Execute via subagent-driven TDD loop.
6. Two-stage review after each task.
7. Provide raw test/build output as proof.
8. Provide step-by-step human manual testing instructions.
9. Deliver the cumulative solution walkthrough and close the issue upon human approval.
```
