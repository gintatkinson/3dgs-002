<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Configuration

The pipeline is configured through a combination of repository layout, project-level governance documents, and the `tessl.json` plugin manifest. This page documents the configuration surface for both specification engineering and feature implementation.

## Repository Layout

A typical project using the pipeline looks like this:

```
<project_root>/
├── skills/                    # Agent skill files (copied or submoduled)
├── rules/                     # Always-loaded governance constraints
├── .pipeline/                 # Project-specific pipeline configuration
│   ├── constitution.md        # Tier 1: Functional constitution
│   └── profiles/              # Tier 2: Implementation profiles
│       ├── react.md
│       ├── flutter.md
│       └── dotnet.md
├── docs/                      # Living documentation
│   ├── epics/                 # Epic markdown files
│   ├── features/              # Feature markdown files
│   ├── user-stories/          # User Story markdown files
│   ├── use-cases/             # Use Case markdown files
│   ├── designs/               # Solution walkthroughs
│   └── decisions/             # Architecture decision records
├── schema/                    # Structural schema source files
├── tests/                     # Project tests
├── scripts/                   # Utility scripts
├── AGENTS.md                  # Agent instructions (optional but recommended)
├── tessl.json                 # Tessl plugin manifest
└── requirements.txt           # Python dependencies for scripts
```

## Tessl Plugin Manifest

**File:** `tessl.json`

This manifest declares the pipeline as a Tessl plugin and points to the skill registry.

Example:
```json
{
  "name": "digital-pipeline-repo",
  "version": "2.0.0",
  "skills": [
    "skills/spec-orchestrator",
    "skills/schema-specification-engineering",
    "skills/spec-user-story-engineering",
    "skills/spec-usecase-engineering",
    "skills/project-constitution",
    "skills/feature-driven-implementation"
  ],
  "rules": [
    "rules/"
  ]
}
```

## Two-Tier Governance

### Tier 1: Functional Constitution

**File:** `.pipeline/constitution.md`

The functional constitution governs all specification work. It is platform-independent and protocol-agnostic.

**Typical sections:**
- Domain Rules
- Model Metamodel and Profile Mapping Standard
- Universal Model Consistency Rules
- Specification Standards
- Agent Behavior
- Universal Quality Gates
- Forbidden Practices

**Read by:**
- `spec-orchestrator`
- `schema-specification-engineering`
- `spec-user-story-engineering`
- `spec-usecase-engineering`
- `feature-driven-implementation`
- `project-constitution`

**Not read by:** Specification workers must ignore implementation profiles.

### Tier 2: Implementation Profiles

**File:** `.pipeline/profiles/<platform>.md`

Implementation profiles govern feature implementation for a specific target platform.

**Typical sections:**
- Platform and Stack Constraints
- Coding Standards
- Testing Mandates
- Build and Deployment
- Security and Ops

**Read by:**
- `feature-driven-implementation` (when targeting that platform)

**Not read by:** Specification workers.

## Environment Variables

The reconciliation and coverage scripts use the following environment variables when arguments are omitted:

| Variable | Purpose | Default |
|---|---|---|
| `SCHEMA_DIR` | Directory containing structural schemas | `<repo_root>/schema` |
| `FEATURES_DIR` | Directory containing feature markdown files | `<repo_root>/docs/features` |

## Agent Configuration

### AGENTS.md (Recommended)

Create an `AGENTS.md` file in the project root to tell any agent where to find the pipeline:

```markdown
# Agent Instructions

## Pipeline Skills
This project uses the Digital Systems Engineering Pipeline.
- Skills: read all SKILL.md files in the configured skills directory.
- Rules: read all files in the configured rules directory.
- Constitution: read the constitution file before any task.
- Implementation profiles: read the implementation profile before implementing features.
```

### Claude Code

If using Tessl:
```bash
tessl init --agent claude-code
tessl install github:gintatkinson/digital-pipeline-repo
```

If using direct copy:
```bash
echo "Read all SKILL.md files in skills/ and all rule files in rules/ before starting any task." >> CLAUDE.md
```

### Cursor / Windsurf / Cascade

If using Tessl:
```bash
tessl init --agent cursor
tessl install github:gintatkinson/digital-pipeline-repo
```

If using direct copy:
- Create `.cursor/rules/pipeline.mdc` or `.windsurf/rules/pipeline.md` referencing the skills and rules directories.

### Gemini CLI

If using Tessl:
```bash
tessl init --agent gemini
tessl install github:gintatkinson/digital-pipeline-repo
```

If using direct copy:
- Reference `./skills/` and `./rules/` in the Gemini CLI session or Antigravity project config.

## Installation Options

### Option 1: Native GitHub Template (Recommended)

To create a new project workspace directly from the template repository on GitHub's servers:

1. Use the GitHub CLI to create the repository on GitHub from the template and clone it locally:
   ```bash
   gh repo create my-new-app --template gintatkinson/digital-pipeline-repo --public --clone
   ```

### Option 2: Direct Copy

Copy `skills/`, `rules/`, `.pipeline/`, and `.agents/` into the project repository.

Stable version:
```bash
git clone https://github.com/<owner>/<template-repo>.git ./.tmp-pipeline
rm -rf ./skills ./rules ./.pipeline ./.agents
cp -RP ./.tmp-pipeline/skills ./
cp -RP ./.tmp-pipeline/rules ./
cp -RP ./.tmp-pipeline/.pipeline ./
cp -RP ./.tmp-pipeline/.agents ./
cp ./.tmp-pipeline/requirements.txt ./
rm -rf ./.tmp-pipeline
```

Refactored version:
```bash
git clone -b refactor https://github.com/<owner>/<template-repo>.git ./.tmp-pipeline
rm -rf ./skills ./rules ./.pipeline ./.agents
cp -RP ./.tmp-pipeline/skills ./
cp -RP ./.tmp-pipeline/rules ./
cp -RP ./.tmp-pipeline/.pipeline ./
cp -RP ./.tmp-pipeline/.agents ./
cp ./.tmp-pipeline/requirements.txt ./
rm -rf ./.tmp-pipeline
```

### Option 3: Git Submodule

Stable version:
```bash
git submodule add https://github.com/<owner>/<template-repo>.git .pipeline-skills
```

Refactored version:
```bash
git submodule add -b refactor https://github.com/<owner>/<template-repo>.git .pipeline-skills
```

Update:
```bash
git submodule update --remote .pipeline-skills
git add .pipeline-skills && git commit -m "chore: update pipeline skills"
```

#### Submodule Path Configuration

When using the Git Submodule method, the skills and rules directories are nested inside `.pipeline-skills/`. Create a `skills.json` file at the project root to register these paths for automatic agent discovery:

```json
{
  "entries": [
    { "path": ".pipeline-skills/skills" }
  ]
}
```

For workspace-scoped rules, update the agent configuration to point to `.pipeline-skills/rules/` instead of `./rules/`.

### Option 4: Tessl Registry

Stable version:
```bash
tessl init --agent gemini --agent claude-code --agent cursor
tessl install github:gintatkinson/digital-pipeline-repo
```

Refactored version:
```bash
tessl init --agent gemini --agent claude-code --agent cursor
tessl install github:gintatkinson/digital-pipeline-repo#refactor
```

## Python Dependencies

The reconciliation and coverage scripts require Python 3 and PyYAML.

```bash
pip install -r requirements.txt
```

Contents of `requirements.txt`:
```
PyYAML
```

## Configuration Checklist

Before running any pipeline:

- [ ] Skills and rules are accessible to the agent.
- [ ] Functional constitution exists (or will be created) at `.pipeline/constitution.md`.
- [ ] For implementation: target implementation profile exists at `.pipeline/profiles/<platform>.md`.
- [ ] Issue tracker CLI is installed and authenticated (e.g., `gh` CLI).
- [ ] Python 3 and PyYAML are installed for scripts.
- [ ] `AGENTS.md` or equivalent references the skills and rules.
- [ ] For Firestore profiles: local emulator is available (`npx firebase-tools emulators:start --only firestore`).
