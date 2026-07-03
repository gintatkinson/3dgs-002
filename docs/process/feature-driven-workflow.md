<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Feature-Driven Autonomous Delivery Workflow

> **Canonical Skill Definition:** [`skills/feature-driven-implementation/SKILL.md`](../../skills/feature-driven-implementation/SKILL.md)
> This document is a human-readable overview. The SKILL.md is the authoritative, machine-consumable definition with full TDD discipline, subagent dispatch, and two-stage review gates.

This document outlines a high-quality, dependency-driven agentic workflow for serially implementing features based on the project's Epics, Features, and User Stories. It enforces strict serialization, interactive design approval, and end-to-end issue tracker lifecycle management.

## 1. Goal Description

To establish a rigorous, serial, and interactive agentic pipeline. Instead of attempting parallel implementation, the AI agent will strictly prioritize work based on architectural dependencies. Each feature undergoes a dedicated lifecycle—from isolated branch creation and interactive design validation to execution, testing, and final release—ensuring maximum alignment with user intent and zero architectural regressions.

## 2. The Agentic Implementation Process

The workflow is broken down into five distinct, sequential phases that govern how every feature is delivered.

### Phase 1: Dependency Mapping & Prioritization (The Backlog)
Before any code is written, the agent analyzes the `docs/` hierarchy (Epics, Features, User Stories) to understand the architectural constraints.
- **Action:** The agent maps the dependency tree (e.g., base node structures must be implemented before link termination endpoints).
- **Output:** A serialized queue of backlog Issues/Features. 
- **Rule:** We strictly operate on **one feature at a time**. We do not move to feature N+1 until feature N is closed and released.

### Phase 2: Checkout & Design Iteration ("The Grill")
Once a feature reaches the top of the queue, the active implementation cycle begins.
- **Action:** 
  1. **Branching:** The agent autonomously checks out a new feature branch from `<default-branch>` using the configured branch checkout command and naming convention (e.g. `git checkout -b <branch_prefix><issue_number>-<short-description>` or as defined by the repository's configuration rules).
  2. **Solution Design:** The agent creates a highly detailed, feature-specific Design & Implementation Plan artifact mapping out exactly what files will change, how the schemas map to the UI, and any trade-offs.
  3. **The Grill:** We enter an interactive review loop. You and I "grill each other" to clarify ambiguities, challenge design choices, and validate adherence to the specifications.
- **Output:** A finalized, mutually approved implementation blueprint. No code is written until absolute consensus is reached.

### Phase 3: Execution & Build
With a finalized plan, the agent moves to execution.
- **Action:** The agent writes the code, updating interfaces, mock services, and components based *only* on the approved plan. 
- **Rule:** If unexpected roadblocks arise during coding, the agent pauses execution and brings the issue back to "The Grill" for resolution.
- **Output:** Working, committed code on the feature branch that builds successfully without linting or compilation errors.

### Phase 4: Testing & Verification
The agent hands the completed build over to you for validation.
- **Action:** The agent starts the local development server (or provides the necessary artifacts) and invites you to test the feature manually.
- **Feedback Loop:** If there are bugs or UI adjustments needed, the agent applies fixes incrementally and pushes new commits to the branch until you are completely satisfied.
- **Output:** A fully verified and robust feature.

### Phase 5: Release & Closure
The final stage of the feature's lifecycle.
- **Action:** 
  1. Once you explicitly accept the feature, the agent merges the feature branch into `<default-branch>` using the configured merge command template.
  2. **Solution Document Creation:** The agent commits the final Walkthrough/Solution document (including a Code Realization Table mapping features/attributes to implemented code) to the configured design directory.
     * **Strict Naming Constraint:** The file MUST be formatted exactly using the tracker issue number (e.g., `feat-<Issue_Number>-solution.md` or `epic-<Issue_Number>-solution.md`, where `<Issue_Number>` is the unique Issue Number). **DO NOT** use the Feature Index number if the Issue Number is different.
     * **Zero-Trust Collision Check:** Before creating the file, search the repository and Git history to ensure the filename does not already exist. If it does, halt and resolve the naming conflict.
  3. The agent pushes the changes to `<default-branch>` and uses the configured issue tracker CLI or API to close the corresponding Issue, explicitly embedding a direct URL link to the committed solution document on the remote standard default branch in the closing comment.
  4. The corresponding local Epic markdown file is updated to check off the feature (`[x]`).
  5. The local and remote feature branches are deleted using the configured branch cleanup commands.
  6. **Agentic Epic Closure:** If all constituent features in the local Epic checklist are now completed (`[x]`), the agent must update the Epic issue's body and close the Epic issue itself on the active issue tracker using the configured tracker CLI or API with an appropriate summary comment.
- **Output:** A clean, released feature with fully linked documentation, and any completed parent Epics successfully closed on the issue tracker, readying the agent to pull the next prioritized feature from Phase 1.

## 3. Multi-Platform Monorepo Support

The pipeline supports deploying the same functional specifications across multiple client distributions/platforms within a single repository using a monorepo structure.

### Project Layout
All platform distributions are isolated in their own configured root directories:
* Configured client application directories (e.g. resolved dynamically from codebase rules or profiles).
* Shareable documentation and platform-independent functional specifications directories.

### Execution Flow
1. **Target Selection:** During Phase 2 ("The Grill"), the developer specifies the target platform.
2. **Profile Loading:** The agent loads the corresponding profile (e.g. from the configured profiles directory) to apply the appropriate build, lint, and testing rules dynamically.
3. **Sequential Branching:** Features are implemented serially per platform using dedicated branches with branch names conforming to the configured platform suffix or branch naming pattern.
4. **Separate Walkthrough Records:** The agent creates separate solution walkthroughs to preserve independent Code Realization Tables, conforming to the configured walkthrough naming pattern (e.g. `feat-<Issue_Number>-<platform>-solution.md`).

