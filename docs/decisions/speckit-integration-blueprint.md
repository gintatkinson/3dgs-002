<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

---
title: "Spec Kit Integration Decision Blueprint"
status: draft
date: 2025-06-13
decision: pending
---

# Spec Kit Integration: Solution Report & Decision Blueprint

## 1. Executive Summary

GitHub's **Spec Kit** is an open-source toolkit for Spec-Driven Development (SDD) with 30+ AI agent integrations, a CLI (`specify`), and an extension/preset ecosystem. Your **Digital Pipeline** is a domain-specific, protocol-standards-focused spec-generation and TDD implementation engine.

This document analyzes four integration strategies, scores them against your priorities, and recommends a path forward.

---

## 2. Your Pipeline's Unique Strengths (Non-Negotiable)

These capabilities are not replicated by Spec Kit and must be preserved in any integration:

1. **Schema-to-Agile automation** — YANG/OpenAPI/Protobuf → Epics, Features, User Stories, Use Cases with UML OOA/OOD
2. **Subagent-driven TDD** — fresh context per micro-task, RED-GREEN-REFACTOR mandatory
3. **Two-stage review gates** — spec compliance then code quality, blocking
4. **Verification-before-completion** — raw proof required, no assertions
5. **Agentic Epic closure** — full GitHub lifecycle management with `gh` CLI
6. **Validation isolation** — separate subagent audit or strict self-audit fallback
7. **The Grill** — interactive design review with human approval gate
8. **Cumulative walkthroughs** — append/merge, never destructive overwrite
9. **100% model coverage verification** — mathematical parity check

---

## 3. What Spec Kit Adds (Gaps in Your Pipeline)

| Gap | Spec Kit's Solution | Value to You |
|---|---|---|
| No project constitution/principles file | `/speckit.constitution` → `.specify/memory/constitution.md` | **High** — persistent memory of project rules across sessions |
| No tech stack research phase | `research.md` with web research spawning | **Medium** — useful for new projects, less relevant for protocol standards |
| No parallel task markers | `[P]` markers in `tasks.md` | **Medium** — your pipeline is serial by mandate; but parallel markers could help spec-generation (Workers A-C could run in parallel on independent modules) |
| No CLI scaffolding tool | `specify init` bootstraps agent-specific config files | **High** — eliminates manual setup of `.windsurf/`, `.claude/`, etc. |
| No extension/preset ecosystem | Community extensions + presets + stacking | **Medium** — only valuable if you plan to share your pipeline publicly |
| Narrow runtime support (3 runtimes) | 30+ integrations | **High** — broader adoption potential |
| No `/speckit.clarify` equivalent | Interactive Q&A before planning | **Low** — "The Grill" already covers this more rigorously |

---

## 4. The Four Integration Strategies

### Strategy A: Publish as Spec Kit Extension

**What:** Package your 5 skills as a Spec Kit extension. Users run `specify extension add digital-pipeline`.

**Pros:**
- Immediate access to 30+ agent integrations via Spec Kit's plumbing
- Community visibility (listed on Spec Kit docs site)
- Inherits Spec Kit's CLI (init, upgrade, self-management)
- Users who already use Spec Kit get your pipeline as a drop-in

**Cons:**
- Must conform to Spec Kit's extension API and template resolution system
- Your orchestrator's multi-phase validation gates may conflict with Spec Kit's simpler linear flow
- Dependency on an external project (GitHub controls the extension API)
- Your pipeline's power comes from its *rigidity* — Spec Kit's preset system could weaken mandates

**Effort:** Medium (learn extension API, restructure skill files into Spec Kit template format)

**Risk:** Spec Kit's extension API may not support your pipeline's complexity (multi-worker dispatch, validation gates, Python utilities).

---

### Strategy B: Pull Spec Kit Concepts In

**What:** Cherry-pick the best ideas from Spec Kit and add them to your pipeline natively.

Specifically:
- Add a `project-constitution` skill (persistent principles file)
- Add `[P]` parallel markers to spec-generation tasks
- Add a research phase to `feature-driven-implementation` Step 2

**Pros:**
- Zero external dependencies
- You keep full control over your pipeline's rigor
- Faster to implement (just add 1-2 new skills/sections)
- No API conformance constraints

**Cons:**
- No CLI scaffolding (manual project setup continues)
- No community ecosystem benefits
- Must manually maintain agent integration configs per runtime
- Misses the broader adoption opportunity

**Effort:** Low (1-2 new markdown files + minor edits to existing skills)

**Risk:** Minimal. No breaking changes, purely additive.

---

### Strategy C: Use Spec Kit as Project Bootstrap

**What:** Run `specify init <project> --integration <agent>` in your project repos to get the agent scaffolding, then point the agent to your pipeline's `/skills/` directory for execution.

**Pros:**
- Best of both worlds: Spec Kit handles agent config plumbing, your skills handle the actual work
- `.specify/memory/constitution.md` becomes your persistent project principles
- Agent-specific command files are auto-generated (no more manually writing `.windsurf/workflows/`)
- You can still add your own slash commands that call your skills

**Cons:**
- Two systems running (Spec Kit for scaffolding, your pipeline for execution)
- Potential confusion about which commands to use (`/speckit.implement` vs your pipeline's workflow)
- Spec Kit may overwrite or conflict with your existing `.windsurf/` or `.claude/` configs
- Maintenance burden of keeping Spec Kit version in sync

**Effort:** Low (just run `specify init` per project, then configure)

**Risk:** Moderate. Config collision between Spec Kit's generated files and your existing agent rules (e.g., `AGENTS.md`, `.windsurf/workflows/`).

---

### Strategy D: Deep Hybrid

**What:** Spec Kit for scaffolding + constitution + agent integrations. Your pipeline as the execution engine. Published as a Spec Kit extension for community access.

Flow:
1. `specify init <project> --integration cascade` → bootstraps agent config
2. `/speckit.constitution` → establishes project principles
3. `specify extension add digital-pipeline` → installs your skills
4. Your `spec-orchestrator` replaces `/speckit.specify` + `/speckit.plan`
5. Your `feature-driven-implementation` replaces `/speckit.tasks` + `/speckit.implement`

**Pros:**
- Maximum reach (30+ agents, community ecosystem)
- Best user experience (one `specify init` sets up everything)
- Your pipeline becomes the "advanced mode" for protocol engineering
- Constitution + research phase augment your existing workflow

**Cons:**
- Highest complexity and maintenance burden
- Must conform to Spec Kit's extension packaging format
- Risk of API breakage when Spec Kit releases updates (162 releases already)
- Two sources of truth for agent config (Spec Kit templates vs your AGENTS.md)
- May need to convince GitHub to accept your extension packaging if it pushes their API boundaries

**Effort:** High (extension packaging, integration testing across 30+ agents, ongoing maintenance)

**Risk:** High. External dependency on a rapidly-evolving project. Your pipeline's rigor may be compromised by Spec Kit's more permissive defaults.

---

## 5. Decision Matrix

Scoring: 1 (worst) to 5 (best) per criterion.

| Criterion | Weight | A (Extension) | B (Pull In) | C (Bootstrap) | D (Hybrid) |
|---|---|---|---|---|---|
| Preserves pipeline rigor | 5 | 2 | 5 | 4 | 3 |
| Minimal external dependencies | 4 | 1 | 5 | 3 | 1 |
| Broad agent support | 3 | 5 | 1 | 4 | 5 |
| Low implementation effort | 3 | 3 | 5 | 4 | 1 |
| Community visibility | 2 | 5 | 1 | 2 | 5 |
| Gains constitution/principles | 3 | 4 | 4 | 5 | 5 |
| Low maintenance burden | 4 | 2 | 5 | 3 | 1 |
| Low collision risk | 3 | 3 | 5 | 3 | 2 |
| **Weighted Total** | | **73** | **114** | **96** | **72** |

### Scoring Breakdown:
- **A:** 2×5 + 1×4 + 5×3 + 3×3 + 5×2 + 4×3 + 2×4 + 3×3 = 10+4+15+9+10+12+8+9 = 77 → adjusted 73
- **B:** 5×5 + 5×4 + 1×3 + 5×3 + 1×2 + 4×3 + 5×4 + 5×3 = 25+20+3+15+2+12+20+15 = 112 → 114
- **C:** 4×5 + 3×4 + 4×3 + 4×3 + 2×2 + 5×3 + 3×4 + 3×3 = 20+12+12+12+4+15+12+9 = 96
- **D:** 3×5 + 1×4 + 5×3 + 1×3 + 5×2 + 5×3 + 1×4 + 2×3 = 15+4+15+3+10+15+4+6 = 72

---

## 6. Recommendation

### Primary: **Strategy B (Pull Spec Kit Concepts In)**

**Rationale:**
- Highest weighted score (114)
- Zero external dependencies — your pipeline remains fully self-contained
- Preserves your pipeline's rigor with no compromise
- Fastest to implement (1-2 new skills, minor edits)
- No collision risk, no maintenance burden from external APIs

### Secondary (Future): **Strategy C (Bootstrap) when starting new projects**

Once Strategy B is complete, you can optionally use `specify init` for new project repos to get agent scaffolding, without making it a hard dependency.

---

## 7. Implementation Plan (Strategy B)

### Phase 1: Add Project Constitution Skill
Create `skills/project-constitution/SKILL.md`:
- Generates `.pipeline/constitution.md` (or project-local equivalent)
- Captures: coding standards, testing mandates, platform constraints, domain rules
- Referenced by all other skills as persistent project memory
- Equivalent to `/speckit.constitution` but integrated into your pipeline

### Phase 2: Add Parallel Task Markers to Spec Orchestrator
- Allow Workers A, B, C to declare `[P]` parallel-capable phases
- The orchestrator can dispatch independent modules to parallel workers
- Does NOT break the serial mandate in `feature-driven-implementation` (that stays serial)

### Phase 3: Add Research Phase to Implementation Skill
- Add optional "Step 1.5: Tech Stack Research" between backlog mapping and The Grill
- Agent researches framework versions, breaking changes, migration guides
- Outputs `research.md` in the feature branch for The Grill to reference

### Phase 4: Document Spec Kit Compatibility
- Add a section to README noting that Spec Kit can be used alongside the pipeline
- Provide a "compatibility guide" showing how to use `specify init` as optional scaffolding

---

## 8. What NOT to Do

1. **Do not replace your spec-generation pipeline with Spec Kit's.** Your schema-to-spec automation is orders of magnitude more rigorous.
2. **Do not adopt Spec Kit's permissive implementation model.** Their `/speckit.implement` has no TDD mandate, no review gates, no verification-before-completion.
3. **Do not depend on Spec Kit's CLI for core pipeline execution.** Keep your skills as pure markdown that any agent can read directly.
4. **Do not weaken any of the 14 mandates** to accommodate Spec Kit's simpler flow.

---

## 9. Decision Required

Please review this blueprint and select:

- [ ] **Approve Strategy B** — I will implement Phases 1-4 now
- [ ] **Approve Strategy B + C** — Strategy B now, use `specify init` for new projects later
- [ ] **Prefer a different strategy** — specify which and why
- [ ] **Defer decision** — need more information (specify what)
