<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Decision Records

This page indexes the architectural and process decision records maintained in the `docs/decisions/` directory. These records capture the reasoning behind major design choices, audit findings, and integration plans.

## Index of Decision Records

| Record | File | Topic |
|---|---|---|
| Consolidated Decision Making Report | `docs/decisions/consolidated_decision_making_report.md` | Cross-cutting decisions and design rationale |
| Pipeline Analysis Report | `docs/decisions/pipeline_analysis_report.md` | In-depth analysis of pipeline structure and behavior |
| Adversarial Audit Report | `docs/decisions/adversarial_audit_report.md` | Results of adversarial audit against pipeline outputs |
| Adversarial Audit Synthesis | `docs/decisions/adversarial_audit_synthesis.md` | Synthesized findings across audits |
| Adversarial Hardcode Audit Report | `docs/decisions/adversarial_hardcode_audit_report.md` | Audit focused on hardcoded assumptions |
| Incident Retrospective | `docs/decisions/incident_retrospective.md` | Post-incident review and remediation |
| Logical UI Adversarial Audit | `docs/decisions/logical_ui_adversarial_audit.md` | UI layer audit findings |
| React Platform Adversarial Audit | `docs/decisions/react_platform_adversarial_audit.md` | React-specific audit findings |
| UML Compliance Agentic Analysis Plan | `docs/decisions/uml_compliance_agentic_analysis_plan.md` | Plan for agentic UML compliance analysis |
| UML Compliance Audit Report | `docs/decisions/uml_compliance_audit_report.md` | UML conformance audit results |
| UML Frontend Alignment Audit | `docs/decisions/uml_frontend_alignment_audit.md` | Alignment between UML models and frontend implementation |
| Speckit Integration Blueprint | `docs/decisions/speckit-integration-blueprint.md` | Integration strategy with GitHub Spec Kit |

## Audit Subdirectory

The `docs/decisions/audits/` directory contains additional audit artifacts:

- `docs/decisions/audits/`

## Design Solutions

The `docs/designs/` directory contains cumulative solution walkthroughs for implemented features:

| Walkthrough | File |
|---|---|
| Adversarial Audit Solution | `docs/designs/feat-adversarial-audit-solution.md` |
| Epic Template Mandate Plan | `docs/designs/feat-epic-template-mandate-plan.md` |
| Epic Template Mandate Solution | `docs/designs/feat-epic-template-mandate-solution.md` |
| Pipeline Audit Solution | `docs/designs/feat-pipeline-audit-solution.md` |
| Use Case Alternate Flows Solution | `docs/designs/feat-usecase-alternate-flows-solution.md` |

## Logical UI Design Report

A consolidated report on logical UI design is maintained at:

- `docs/consolidated_logical_ui_design_report.md`

## Feature Design Documents

Detailed design documents for specific features:

- `docs/feat-decoupled-persistence-layout-engine-design.md`
- `docs/feat-firestore-persistence-adapter-design.md`
- `docs/feat-hardware-decoupled-persistence-design.md`

## How to Add a Decision Record

1. Create a new markdown file in `docs/decisions/` with a descriptive name.
2. Include a header with title, date, status, and context.
3. Document the decision, alternatives considered, and consequences.
4. Link to the new record from this wiki page.
5. Commit:
   ```bash
   git add docs/decisions/<new-record>.md wiki/Decision-Records.md
   git commit -m "docs: add decision record for <topic>"
   ```

## Decision Record Template

```markdown
---
title: "Decision Record: [Title]"
date: "YYYY-MM-DD"
status: "proposed | accepted | deprecated | superseded"
---

# Context

Describe the problem or question.

# Decision

State the decision clearly.

# Consequences

List positive and negative consequences.

# Alternatives Considered

Document alternatives and why they were rejected.
```
