<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Rules Reference

Rules are constraints that are **always loaded** into every agent session, regardless of which skill is active. They live in the `rules/` directory and are distributed into agent-specific config files when the pipeline is installed via Tessl.

## Rule Inventory

| Rule | File | Purpose |
|---|---|---|
| [Constitution First](#constitution-first) | `rules/constitution-first.md` | Read the constitution before any task |
| [Serial Execution](#serial-execution) | `rules/serial-execution.md` | One feature at a time |
| [TDD Mandate](#tdd-mandate) | `rules/tdd-mandate.md` | Enforce RED-GREEN-REFACTOR |
| [Verification Required](#verification-required) | `rules/verification-required.md` | Raw proof before completion |
| [No Browser Automation](#no-browser-automation) | `rules/no-browser-automation.md` | No ad-hoc browser scripts |
| [Tracker Source of Truth](#tracker-source-of-truth) | `rules/tracker-source-of-truth.md` | Use tracker CLI, not local state |
| [Platform Independence](#platform-independence) | `rules/platform-independence.md` | Specs must be functional |
| [User Authorization Lock](#user-authorization-lock) | `rules/user-authorization-lock.md` | Human approval for sensitive actions |

## Constitution First

**File:** `rules/constitution-first.md`

**Enforcement:** Always read the project constitution before beginning any pipeline task.

**Required reads:**
1. Functional constitution (e.g., `.pipeline/constitution.md`) — domain rules, spec standards, agent behavior, quality gates.
2. Implementation profile (e.g., `.pipeline/profiles/<platform>.md`) — platform-specific coding standards, testing mandates, build config.

**Hard constraints:**
- If the functional constitution exists, you must read it.
- If implementing and no profile exists, halt and ask the human to create one.
- If a change conflicts with the constitution, halt and escalate.
- Specification workers must **not** read implementation profiles.

## Serial Execution

**File:** `rules/serial-execution.md`

**Enforcement:** Implement exactly one feature at a time.

**Hard constraints:**
- Do not start feature N+1 until feature N is fully verified, merged, documented, and closed.
- Do not parallelize feature implementation across agents.
- No batching of unrelated features.

## TDD Mandate

**File:** `rules/tdd-mandate.md`

**Enforcement:** All implementation must follow RED-GREEN-REFACTOR.

**The cycle:**
1. **RED:** Write a failing test first. Run it. Confirm it fails.
2. **GREEN:** Write minimal code to pass. Run it. Confirm it passes.
3. **REFACTOR:** Clean up while keeping tests green.

**Hard constraints:**
- Code written before its failing test must be deleted and re-implemented after the test.
- Never skip the "confirm it fails" step.
- Each micro-task must have a driving test.
- Use the test framework specified in the implementation profile.

## Verification Required

**File:** `rules/verification-required.md`

**Enforcement:** Before declaring any task, micro-task, or feature complete, provide concrete proof of correctness.

**Valid proof:**
- Raw test output
- Raw build output
- Explicit file-content verification

**Invalid proof:**
- "It works" or "tests pass" without pasted evidence
- Summaries without verification
- Assumptions from prior steps

## No Browser Automation

**File:** `rules/no-browser-automation.md`

**Enforcement:** No ad-hoc browser scripts, headless engines, or automation tools.

**Allowed:**
- Manual UI verification
- Project-approved E2E framework (e.g., Playwright if configured in the profile)

**Forbidden:**
- Writing one-off scripts to click through UI
- Using headless browsers not part of the project test suite
- Automating login or credential flows

## Tracker Source of Truth

**File:** `rules/tracker-source-of-truth.md`

**Enforcement:** The issue tracker is the canonical source of backlog state.

**Hard constraints:**
- Query the tracker CLI for issue status.
- Do not rely on local files or checklists for backlog truth.
- Update tracker issues before updating local markdown files.

## Platform Independence

**File:** `rules/platform-independence.md`

**Enforcement:** Specifications must be functional and platform-independent.

**Hard constraints:**
- No framework names in Epics, Features, User Stories, or Use Cases.
- No implementation-specific dependencies in specification artifacts.
- Platform-specific details belong only in implementation profiles and solution walkthroughs.

## User Authorization Lock

**File:** `rules/user-authorization-lock.md`

**Enforcement:** Sensitive or destructive actions require explicit human approval.

**Scope includes:**
- Deleting files, branches, or issues
- Modifying the constitution
- Changing CI/CD or deployment configuration
- Executing commands with broad system impact

## Behavioral Triggers

**File:** `rules/behavioral_triggers.json`

This file contains machine-parseable trigger definitions for rule enforcement. It may include patterns, keywords, or conditions that cause an agent to pause and ask for confirmation.

## Rule Distribution

When installed via Tessl, rules are distributed into agent-specific configuration:

- **Claude Code:** `CLAUDE.md`
- **Cursor / Windsurf / Cascade:** `.cursor/rules/` or `.windsurf/rules/`
- **Gemini CLI:** `AGENTS.md` or equivalent

Without Tessl, agents can read rules directly from the `rules/` directory.

## Rule Conflict Resolution

If a rule conflicts with a skill instruction:

1. Rules are non-negotiable.
2. If the skill instruction appears to require violating a rule, halt and escalate to the human.
3. Document the conflict in the task tracking file.
