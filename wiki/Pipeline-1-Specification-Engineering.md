<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Pipeline 1: Specification Engineering

Pipeline 1 transforms a protocol standard and its structural schemas into a complete, deterministic Agile backlog tracked in the configured issue tracker. The output is a mathematically bounded requirements matrix: every schema element has a corresponding feature, every operational scenario has a user story, and every system interaction has a formal UML use case.

## Purpose

- Convert ambiguous standards into precise, behavior-driven artifacts.
- Enforce 100% coverage of structural models.
- Ensure cross-view consistency between class diagrams, sequence diagrams, and use case diagrams.
- Produce a tracker-backed backlog that implementation agents can consume without reinterpreting the standard.

## Prerequisites

1. **Structural schemas** in a supported format (YANG, OpenAPI, Protobuf, YAML, etc.).
2. **Normative specification document** (RFC chapter, 3GPP section, IEEE standard, etc.).
3. **Configured issue tracker** (GitHub Issues via `gh` CLI by default).
4. **Functional constitution** (optional but recommended at `.pipeline/constitution.md`).

## The Five Phases

### Phase 1: Structural Extraction

- **Skill:** `schema-specification-engineering` (Worker A)
- **Goal:** Identify all Epics and Features from the structural schema.

**Execution details:**
- Parse the schema to build a symbol table of classes, components, attributes, operations, and constraints.
- Map schema nodes to Epics (cohesive structural containers) and Features (granular technical building blocks).
- For each Epic or Feature, dispatch a fresh, context-isolated subagent to draft the markdown specification.
- Register Features first, then inject their Issue IDs into the Epic checklist, then register Epics.

**Validation gate:**
- Query the issue tracker (`gh issue list --limit 1000 --state all --json number,title,state,labels`).
- Verify that every Epic and Feature exists and is interlinked.
- Do not proceed to Phase 2 until this gate passes.

### Phase 2: Behavioral Extraction

- **Skill:** `spec-user-story-engineering` (Worker B)
- **Goal:** Extract BDD User Stories from operational and deployment chapters of the specification.

**Execution details:**
- Parse operational scenarios, state transitions, and calculations.
- Draft one User Story per scenario.
- Each User Story must follow the Given-When-Then format and map to required Features.
- Register stories in the tracker with the `user-story` label.

**Validation gate:**
- Verify that `user-story` issues exist in the tracker.
- Check that tasklists in the story bodies render the intersecting Feature IDs created in Phase 1.

### Phase 3: System Interaction Extraction

- **Skill:** `spec-usecase-engineering` (Worker C)
- **Goal:** Extract formal UML System Use Cases from the specification.

**Execution details:**
- Identify actors, preconditions, main success scenarios, alternate flows, and postconditions.
- Draft one Use Case per system interaction.
- Build a Realization Matrix linking each Use Case to the User Stories and Features it realizes.
- Register use cases with the `use-case` label.

**Validation gate:**
- Verify that `use-case` issues exist in the tracker.
- Confirm that the Realization Matrix links back to User Stories and Features.

### Phase 4: Reconciliation and Verification

- **Worker D:** Backlog reconciliation
- **Coverage Check:** UML compliance and model coverage linter

**Backlog reconciliation script:**
```bash
./skills/spec-orchestrator/scripts/reconcile_backlog.py
```

Responsibilities:
- Parse frontmatter with PyYAML to prevent block erasure.
- Query the issue tracker and sync checkbox states in local markdown files.
- Perform dependency issue hallucination checks.
- Auto-close completed Epics, User Stories, and Use Cases.

**UML coverage verification script:**
```bash
./skills/spec-orchestrator/scripts/verify_model_coverage.py [schema_dir] [features_dir]
```

Responsibilities:
- Parse raw schemas and Mermaid diagram blocks.
- Build symbol tables for class, sequence, and use-case diagrams.
- Verify 100% schema coverage in class diagrams.
- Validate OMG UML 2.5.1 metamodel conformance.
- Check cross-view semantic rules (isolated classes, lifeline aliases, open return arrows, system boundary use cases, correct extend arrow directionality).

**Validation gate:**
- Both scripts must exit with code 0.
- All completed tasks must be synced to the tracker.
- Model coverage must be exactly 100%.

### Phase 5: Final Reporting

- Summarize the end-to-end execution.
- Provide direct links to:
  - Epics
  - Features
  - User Stories
  - Use Cases
- Declare the protocol module "Fully Specification-Engineered and Verified."

## Item-Level Subagent Context Isolation

Every individual Epic, Feature, User Story, and Use Case must be processed by a fresh subagent with an isolated context. The coordinator must never pass the history of other items to the subagent.

**Allowed context per subagent:**
- Relevant schema node(s) or specification paragraph(s)
- The specific template guidelines (Feature, User Story, or Use Case)
- Core project rules and the functional constitution

**Forbidden context:**
- History of other items generated in the same run
- Prior drafts, assumptions, or decisions from other items

## Parallel Dispatch Convention

Phases marked with `[P]` can run in parallel on multi-agent runtimes when there are no data dependencies between them and each worker operates on independent schema modules.

| Phase | Parallel? | Reason |
|---|---|---|
| Phase 1 | No | Epics depend on Feature IDs |
| Phase 2 | Yes | Independent of Phase 3; produces User Stories |
| Phase 3 | Yes | Queries User Story IDs from Phase 2 as they become available |
| Phase 4 | No | Depends on outputs from Phases 2 and 3 |
| Phase 5 | No | Final reporting depends on all prior phases |

On single-agent runtimes (Cascade, Windsurf, Devin), execute all phases sequentially.

## Error Recovery

If any phase fails:

1. **Do not proceed** to the next phase.
2. **Log the exact error** (stderr, exit code, API response).
3. **Attempt remediation once** by re-running the failed step.
4. **File an upstream bug** if the failure appears to be a pipeline tooling bug:
   ```bash
   gh issue create --repo gintatkinson/digital-pipeline-repo \
     --title "Tooling Bug: [Command] failed" \
     --body-file [payload_path] \
     --label "bug"
   ```
5. **Escalate to the user** with the full error context and the upstream issue URL.
6. **Never skip a validation gate.**

## Output Taxonomy

| Label | Purpose | Created By |
|---|---|---|
| `epic` | High-level structural container | Phase 1 |
| `feature` | Granular technical building block | Phase 1 |
| `user-story` | BDD scenario mapped to Features | Phase 2 |
| `use-case` | Formal UML system interaction | Phase 3 |

## Typical Prompt

```
Adopt the specification orchestrator skill. I want to specification-engineer [Protocol Standard].

1. The structural schemas are located at [path to schemas].
2. The normative specification documents are located at [path to specs].

Execute the full digital engineering pipeline.
```
