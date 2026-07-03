<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Workflows

This page provides reusable command sequences, prompt templates, and operational checklists for the most common uses of the Digital Systems Engineering Pipeline.

## Onboarding a New Project

1. Install the pipeline via direct copy, submodule, or Tessl.
2. Create the governance structure:
   ```bash
   mkdir -p .pipeline/profiles
   ```
3. Use the `project-constitution` skill to draft `.pipeline/constitution.md` and the required implementation profiles.
4. Create `AGENTS.md` pointing to skills, rules, constitution, and profiles.
5. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```
6. Authenticate the tracker CLI:
   ```bash
   gh auth login
   ```

## Running the Specification Pipeline

### Prompt Template

```
Adopt the specification orchestrator skill. I want to specification-engineer [Protocol Standard, e.g., RFC 8345].

1. The structural schemas are located at [path to schemas, e.g., ./schema].
2. The normative specification documents are located at [path to specs, e.g., ./docs/specs].

Execute the full digital engineering pipeline.
```

### Manual Phase Execution

If the orchestrator needs to be run phase by phase:

**Phase 1 — Structural extraction:**
```
Adopt the schema-specification-engineering skill. Structural schemas are at [path]. Draft all Epics and Features, then register them in the tracker.
```

**Phase 2 — User stories:**
```
Adopt the spec-user-story-engineering skill. The normative spec is at [path]. Draft User Stories for every operational scenario and map them to the Features created in Phase 1.
```

**Phase 3 — Use cases:**
```
Adopt the spec-usecase-engineering skill. The normative spec is at [path]. Draft UML System Use Cases and link them to the User Stories and Features.
```

**Phase 4 — Reconciliation and coverage:**
```bash
./skills/spec-orchestrator/scripts/reconcile_backlog.py
./skills/spec-orchestrator/scripts/verify_model_coverage.py [schema_dir] [features_dir]
```

## Implementing a Feature

### Prompt Template

```
Adopt the feature-driven implementation skill. I want to implement Feature [#Issue Number] targeting platform [platform identifier].

Execute the full delivery workflow with TDD execution discipline:
1. Map dependencies from the backlog directory (e.g., docs/epics/, docs/features/). Order base dependencies first.
2. Draft an implementation plan covering the full vertical slice: persistence, transformation, interface, and test plan.
3. Decompose into micro-tasks (2-5 min each, with a driving test per task).
4. Present the plan for approval (The Grill).
5. Execute via subagent-driven TDD loop.
6. Two-stage review after each task.
7. Provide raw test/build output as proof.
8. Provide step-by-step human manual testing instructions.
9. Deliver the cumulative solution walkthrough and close the issue upon human approval.
```

### Feature Branch Checklist

- [ ] Branch name follows project convention (e.g., `feat/<N>-<desc>`).
- [ ] Implementation plan is approved by the human (The Grill).
- [ ] Every micro-task has a driving test.
- [ ] RED-GREEN-REFACTOR is followed for each micro-task.
- [ ] Two-stage review passes for each micro-task.
- [ ] Raw test/build output is pasted into the tracking file.
- [ ] Solution walkthrough is created at `docs/designs/feat-<Issue_Number>-solution.md`.
- [ ] Feature issue is closed with a link to the walkthrough.
- [ ] Parent Epic checklist is updated and pushed.
- [ ] Epic is closed automatically if all features are complete.
- [ ] Feature branch is deleted locally and remotely.

## Adding a New Implementation Platform

1. Human request: "I want to implement on [platform]."
2. Use the `project-constitution` skill to gather implementation principles.
3. Generate `.pipeline/profiles/<platform>.md`.
4. Update `AGENTS.md` to reference the new profile.
5. Commit:
   ```bash
   git add .pipeline/profiles/<platform>.md AGENTS.md
   git commit -m "docs: add implementation profile for <platform>"
   ```

## Updating the Constitution

1. Human request: "Update the constitution to require [new rule]."
2. Read the existing `.pipeline/constitution.md`.
3. Propose the amendment and wait for human approval.
4. Append or refine the relevant section; never destructively overwrite unrelated sections.
5. Update `last_updated` in the frontmatter.
6. Commit:
   ```bash
   git add .pipeline/constitution.md
   git commit -m "docs: update constitution — <summary>"
   ```

## Running Reconciliation

```bash
./skills/spec-orchestrator/scripts/reconcile_backlog.py
```

What it does:
- Parses frontmatter with PyYAML.
- Queries the issue tracker.
- Syncs checkbox states in local markdown.
- Performs dependency issue hallucination checks.
- Auto-closes completed Epics, User Stories, and Use Cases.

## Running UML Coverage Verification

```bash
./skills/spec-orchestrator/scripts/verify_model_coverage.py [schema_dir] [features_dir]
```

What it does:
- Parses raw schemas and Mermaid diagrams.
- Builds class/sequence/use-case symbol tables.
- Verifies 100% schema coverage in class diagrams.
- Validates UML 2.5.1 metamodel conformance.
- Checks cross-view semantic consistency.

## Common Tessl Commands

Install stable version:
```bash
tessl init --agent claude-code --agent cursor --agent gemini
tessl install github:gintatkinson/digital-pipeline-repo
```

Install refactored version:
```bash
tessl init --agent claude-code --agent cursor --agent gemini
tessl install github:gintatkinson/digital-pipeline-repo#refactor
```

Review a skill:
```bash
tessl skill review skills/spec-orchestrator --threshold 80
```

Start MCP server:
```bash
tessl mcp start
```

## Manual Verification Templates

### Specification Pipeline Verification

- [ ] Phase 1 created all expected Epics and Features.
- [ ] Feature IDs are correctly injected into Epic checklists.
- [ ] Phase 2 created all expected User Stories.
- [ ] User Stories link to Features.
- [ ] Phase 3 created all expected Use Cases.
- [ ] Use Cases link to User Stories and Features.
- [ ] Reconciliation script ran without errors.
- [ ] Coverage linter reports 100%.
- [ ] All tracker labels (`epic`, `feature`, `user-story`, `use-case`) exist.

### Feature Implementation Verification

- [ ] Feature branch is checked out.
- [ ] Implementation plan is approved.
- [ ] All micro-tasks are complete.
- [ ] All tests pass.
- [ ] Build/lint passes.
- [ ] Solution walkthrough is committed.
- [ ] Feature issue is closed.
- [ ] Epic checklist is updated.
- [ ] Manual testing instructions are documented.
