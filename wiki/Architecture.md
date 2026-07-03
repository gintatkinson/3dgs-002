<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Architecture

The Digital Systems Engineering Pipeline uses a **Master-Worker architecture** divided into two distinct pipelines: one for specification engineering and one for feature implementation. The entire toolchain is runtime-agnostic, composed of markdown skill files that any agent can read, plus optional Python scripts for reconciliation and UML coverage verification.

## High-Level Flow

```
┌─────────────────────────────────────────┐
│  Structural Schema + Normative Spec     │
│  (YANG, OpenAPI, Protobuf, RFC, etc.)   │
└───────────────────┬─────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│  Pipeline 1: Specification Engineering    │
│  Orchestrator + Workers A/B/C/D         │
│  Epics, Features, User Stories,         │
│  Use Cases, Reconciliation,             │
│  UML Coverage Verification                │
└───────────────────┬─────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│  Configured Issue Tracker               │
│  (GitHub Issues, etc.)                  │
└───────────────────┬─────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│  Pipeline 2: Feature Implementation     │
│  Governance + Implementation Module     │
│  TDD, Micro-Tasks, Two-Stage Review,    │
│  Automated Closure                        │
└─────────────────────────────────────────┘
```

## Pipeline 1: Specification Engineering

Pipeline 1 is orchestrated by the `spec-orchestrator` skill and executes five phases.

### Phase 1: Structural Extraction (Worker A)

- **Skill:** `schema-specification-engineering`
- **Input:** Raw structural schema files
- **Output:** `epic` and `feature` issues in the tracker
- **Key behavior:** Creates Features first, captures their Issue IDs, then injects those IDs into Epic checklists before registering Epics.

### Phase 2: Behavioral Extraction (Worker B)

- **Skill:** `spec-user-story-engineering`
- **Input:** Normative specification document
- **Output:** `user-story` issues mapped to Features
- **Parallel marker:** `[P]`

### Phase 3: System Interaction Extraction (Worker C)

- **Skill:** `spec-usecase-engineering`
- **Input:** Normative specification document
- **Output:** `use-case` issues mapped to User Stories and Features
- **Parallel marker:** `[P]`

### Phase 4: Reconciliation and Verification (Worker D)

- **Backlog Reconciliation:** `skills/spec-orchestrator/scripts/reconcile_backlog.py`
- **UML Coverage / Conformance:** `skills/spec-orchestrator/scripts/verify_model_coverage.py`
- **Output:** Synced checkbox states, auto-closed completed items, 100% model coverage report

### Phase 5: Final Reporting

- Summary of all created artifacts
- Direct links to tracker matrices
- Formal declaration that the protocol module is fully specification-engineered

## Pipeline 2: Feature Implementation

Pipeline 2 is governed by the `project-constitution` skill and executed by the `feature-driven-implementation` skill.

### Governance Layer

- **Functional Constitution:** `.pipeline/constitution.md` — platform-independent rules
- **Implementation Profiles:** `.pipeline/profiles/<platform>.md` — platform-specific rules

### Implementation Layer

The `feature-driven-implementation` skill executes six steps:

1. Backlog and dependency mapping
2. Tech stack research (optional)
3. Checkout and plan review (The Grill)
4. Subagent-driven TDD vertical slice execution
5. Verification and testing
6. Release, closure, and agentic Epic closure

## Runtime Model

### Multi-Agent Runtimes

In Claude Code, Gemini CLI, or other environments with native subagent support:

- Phases 2 and 3 of Pipeline 1 can run in parallel.
- Each micro-task in Pipeline 2 is dispatched to a fresh implementer subagent.
- Separate reviewer subagents perform Stage 1 and Stage 2 reviews.

### Single-Agent Runtimes (Cascade / Windsurf / Devin)

- All phases run sequentially.
- Item-level context isolation is simulated by explicitly resetting context and re-reading target files.
- The coordinator performs self-audit for both review stages.

## Governance Injection

Rules in the `rules/` directory are always loaded, regardless of which skill is active. They are the project's non-negotiable constraints.

```
┌─────────────────────────────────────────┐
│           Rules (always loaded)          │
│  serial-execution, tdd-mandate,          │
│  verification-required,                  │
│  constitution-first, etc.               │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│         Skills (loaded on task)          │
│  spec-orchestrator,                      │
│  feature-driven-implementation,          │
│  project-constitution, etc.               │
└─────────────────────────────────────────┘
```

## Key Files and Directories

| Path | Purpose |
|---|---|
| `skills/` | Agent skill markdown files |
| `rules/` | Always-loaded governance constraints |
| `.pipeline/constitution.md` | Functional constitution (created per project) |
| `.pipeline/profiles/<platform>.md` | Platform-specific implementation profiles |
| `docs/epics/` | Epic markdown files (functional) |
| `docs/features/` | Feature markdown files (functional) |
| `docs/user-stories/` | User Story markdown files (functional) |
| `docs/use-cases/` | Use Case markdown files (functional) |
| `docs/designs/` | Solution walkthroughs (implementation) |
| `schema/` | Structural schema source files |
| `scripts/` | Reconciliation and coverage verification scripts |

## Tessl Integration

When installed via Tessl, the pipeline is distributed as a version-locked plugin:

- Rules are auto-injected into agent-specific config files (`.cursor/rules/`, `CLAUDE.md`, `AGENTS.md`).
- Skills are loaded via MCP or the `.tessl/` directory.
- `tessl skill review` can score structural quality and act as a CI gate.
- `tessl mcp start` serves structured context to prevent context-window overflow.
