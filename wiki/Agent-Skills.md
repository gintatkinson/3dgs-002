<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Agent Skills Reference

Agent skills are markdown files under the `skills/` directory. Each skill follows the [Agent Skills specification](https://agentskills.io/specification) and is designed to be read by an AI agent at task time. Skills are loaded on demand, unlike rules which are always loaded.

## Skill Inventory

| Skill | Name | Category | Risk | Purpose |
|---|---|---|---|---|
| [spec-orchestrator](#spec-orchestrator) | spec-orchestrator | orchestration | medium | Master command for end-to-end specification engineering |
| [schema-specification-engineering](#schema-specification-engineering) | schema-specification-engineering | specification | medium | Worker A: structural extraction into Epics and Features |
| [spec-user-story-engineering](#spec-user-story-engineering) | spec-user-story-engineering | specification | medium | Worker B: behavioral extraction into User Stories |
| [spec-usecase-engineering](#spec-usecase-engineering) | spec-usecase-engineering | specification | medium | Worker C: system interaction extraction into UML Use Cases |
| [project-constitution](#project-constitution) | project-constitution | governance | low | Establishes two-tier functional + implementation governance |
| [feature-driven-implementation](#feature-driven-implementation) | feature-driven-implementation | implementation | low | TDD-driven feature delivery with two-stage review |

## spec-orchestrator

- **File:** `skills/spec-orchestrator/SKILL.md`
- **Version:** 2.0
- **Compatibility:** Claude Code, Gemini CLI, Cursor, Copilot, Cascade
- **Dependencies:** `gh` CLI, `git`

**Purpose:** Orchestrates the five-phase specification engineering pipeline by dispatching Worker A, Worker B, and Worker C, then running Worker D (reconciliation) and the coverage linter.

**Key responsibilities:**
- Validate pre-flight checklist.
- Enforce item-level subagent context isolation.
- Manage parallel dispatch markers `[P]`.
- Run validation gates between phases.
- Handle error recovery and automated upstream bug reporting.
- Produce final summary with direct links to tracker artifacts.

**Phases orchestrated:**
1. Phase 1: Structural Extraction (Worker A)
2. Phase 2: Behavioral Extraction (Worker B) — `[P]`
3. Phase 3: System Interaction Extraction (Worker C) — `[P]`
4. Phase 4: Reconciliation and Verification (Worker D + Coverage Check)
5. Phase 5: Final Reporting

## schema-specification-engineering

- **File:** `skills/schema-specification-engineering/SKILL.md`
- **Role:** Worker A
- **Input:** Structural schemas
- **Output:** `epic` and `feature` issues

**Purpose:** Parses raw schemas and breaks down structural models into Epics and Features with exhaustive Given-When-Then acceptance criteria, platform scoping, and verbatim spec context injection.

**Key behaviors:**
- Build a symbol table from schema nodes.
- Detect duplicates to ensure idempotent re-runs.
- Register Features first, then Epics with Feature ID checklists.
- Respect functional constitution constraints (domain rules, spec standards).

## spec-user-story-engineering

- **File:** `skills/spec-user-story-engineering/SKILL.md`
- **Role:** Worker B
- **Input:** Normative specification text
- **Output:** `user-story` issues

**Purpose:** Parses operational and deployment chapters to extract BDD User Stories modeled on UML OOA/OOD principles.

**Key behaviors:**
- Draft each User Story as a fresh, isolated subagent task.
- Build a Cross-Cutting Matrix linking scenarios to Features.
- Use Given-When-Then format for acceptance criteria.
- Include duplicate detection.

## spec-usecase-engineering

- **File:** `skills/spec-usecase-engineering/SKILL.md`
- **Role:** Worker C
- **Input:** Normative specification text
- **Output:** `use-case` issues

**Purpose:** Extracts formal UML System Use Cases including actors, preconditions, main success scenarios, alternate flows, and postconditions.

**Key behaviors:**
- Draft each Use Case as a fresh, isolated subagent task.
- Build a Realization Matrix linking Use Cases to User Stories and Features.
- Ensure UML 2.5.1 conformance and cross-view consistency.

## project-constitution

- **File:** `skills/project-constitution/SKILL.md`
- **Version:** 2.0
- **Risk:** low
- **Dependencies:** None

**Purpose:** Establishes a project's two-tier governance: a functional constitution and platform-specific implementation profiles.

**Core mandates:**
1. **Functional/Implementation Separation:** Spec workers must not read implementation profiles.
2. **One Constitution, Many Profiles:** One `.pipeline/constitution.md` and zero or more `.pipeline/profiles/<platform>.md` files.
3. **Cumulative, Never Destructive:** Append and refine; never delete established principles without human approval.
4. **Human Authored, Agent Enforced:** Humans write the constitution; agents enforce it.
5. **Profile Selection at Implementation Time:** The target platform selects the profile to read.

**Use when:**
- Setting up a new project
- Onboarding agents
- Adding a new implementation platform
- Updating project-wide standards or quality gates

## feature-driven-implementation

- **File:** `skills/feature-driven-implementation/SKILL.md`
- **Version:** 2.0
- **Risk:** low
- **Dependencies:** `git`, configured issue tracker

**Purpose:** Implements prioritized Agile features with subagent-driven TDD, micro-task decomposition, two-stage review gates, and automated Epic closure.

**Core mandates:** 14 execution rules (serial execution, The Grill, traceability, agentic Epic closure, verification isolation, tracker as source of truth, cumulative walkthroughs, validation isolation, TDD, micro-task decomposition, subagent-driven development, two-stage review, verification-before-completion, inter-task code review).

**Workflow:**
1. Backlog and dependency mapping
2. Optional tech stack research
3. Checkout and plan review (The Grill)
4. Subagent-driven TDD vertical slice execution
5. Verification and testing
6. Release, closure, and agentic Epic closure

## Skill Loading Matrix

| Skill | Reads Functional Constitution | Reads Implementation Profile |
|---|---|---|
| `spec-orchestrator` | Yes | No |
| `schema-specification-engineering` | Yes | No |
| `spec-user-story-engineering` | Yes | No |
| `spec-usecase-engineering` | Yes | No |
| `project-constitution` | Yes | Yes (when creating profiles) |
| `feature-driven-implementation` | Yes | Yes |

## Skill Distribution via Tessl

When the pipeline is installed via Tessl:

- `tessl init --agent <agent>` configures the target agent.
- `tessl install github:gintatkinson/digital-pipeline-repo` installs the stable version.
- `tessl install github:gintatkinson/digital-pipeline-repo#refactor` installs the refactored version.
- `tessl skill review skills/<skill> --threshold 80` scores skill quality for CI gates.
- `tessl mcp start` serves version-locked context via MCP.
