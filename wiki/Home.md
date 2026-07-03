<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Digital Systems Engineering Pipeline Wiki

Welcome to the deep wiki for the **Digital Systems Engineering Pipeline** (also known as the Builders Project). This is a comprehensive knowledge base for the agentic toolchain that transforms protocol standards into deterministic, behavior-driven Agile backlogs and then implements them with rigorous, verifiable engineering discipline.

## What This Pipeline Does

This repository contains a suite of autonomous AI agent skills that perform two major functions:

1. **Specification Engineering (Pipeline 1):** Reads structural schemas and normative specification documents, then produces a complete, interlinked backlog of Epics, Features, User Stories, and UML Use Cases in the configured issue tracker.
2. **Feature Implementation (Pipeline 2):** Implements the backlog items using subagent-driven TDD execution, micro-task decomposition, two-stage review gates, and automated Epic closure.

The pipeline is designed for safety-critical and protocol-heavy domains where requirements must be traceable, specifications must be platform-independent, and implementation must be evidence-backed.

## Quick Start

- **New here?** Read [Architecture](Architecture) and [Pipeline 1: Specification Engineering](Pipeline-1-Specification-Engineering).
- **Ready to implement?** See [Pipeline 2: Feature Implementation](Pipeline-2-Feature-Implementation) and [Workflows](Workflows).
- **Need a reference?** Browse [Agent Skills](Agent-Skills), [Rules](Rules), or [Configuration](Configuration).
- **Something went wrong?** Check [Troubleshooting](Troubleshooting).

## Wiki Map

| Section | Purpose |
|---|---|
| [Architecture](Architecture) | Master-worker design, pipeline flow, and runtime model |
| [Pipeline 1: Specification Engineering](Pipeline-1-Specification-Engineering) | Transforming schemas and specs into tracked Agile artifacts |
| [Pipeline 2: Feature Implementation](Pipeline-2-Feature-Implementation) | TDD-driven feature delivery and automated closure |
| [Agent Skills](Agent-Skills) | Deep reference for every skill in the `skills/` directory |
| [Rules](Rules) | Always-loaded governance constraints |
| [Configuration](Configuration) | Project constitution, implementation profiles, and setup |
| [Workflows](Workflows) | Common prompts, command sequences, and examples |
| [Decision Records](Decision-Records) | Index of architectural and process decisions |
| [Troubleshooting](Troubleshooting) | Common failures, recovery steps, and escalation paths |

## Design Principles

- **Platform Independence:** Specifications describe *what* the system must do, never *how* it is built.
- **Mathematical Boundedness:** Every schema element must map to a feature; every dynamic behavior must reference a defined structural element.
- **Evidence-Based Completion:** No task is complete without raw test output, build output, or explicit file verification.
- **Context Isolation:** Each item is processed by a fresh subagent to prevent drift, contamination, and confirmation bias.
- **Human-in-the-Loop:** The Grill is the mandatory interactive review gate before any code is written.

## External Links

- **Repository:** https://github.com/gintatkinson/digital-pipeline-repo
- **Skill Registry Format:** https://agentskills.io/specification
- **Distribution Platform:** https://tessl.io
