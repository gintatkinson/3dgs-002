# Phoenix Plan — New Clean Repository

**Goal:** New repo with only source code, governance, and the v2.0 skill. No history. No bugs. No scratch files. No audit debris.

---

## 1. What Stays

| Directory/File | Reason |
|----------------|--------|
| `app_flutter/` | The application — all source, tests, config |
| `cesium_native_bridge/` | C++ FFI bridge |
| `third_party/` | Cesium native submodule |
| `skills/adversarial-code-auditor/` | v2.0 skill (the working tool) |
| `skills/*/` (all 9) | Pipeline skills |
| `.pipeline/` | Constitution, profiles, logical-ui specs |
| `rules/` | Agent governance rules |
| `.agents/` | Agent behavior rules |
| `.github/` | CI/CD workflows |
| `docs/` | Select files only (see below) |
| `README.md` | Project overview |
| `LICENSE` | License |
| `requirements.txt` | Python deps |
| `firebase.json` | Firebase config |
| `firestore.rules` | Firestore rules |
| `.gitignore` | Ignore rules |
| `.gitmodules` | Submodule config |
| `tessl.json` | Skill distribution config |

## 2. What Goes

| Directory/File | Reason |
|----------------|--------|
| `scratch/` | Temporary plans, audit debris |
| `build/` | CMake build artifacts |
| `.pytest_cache/` | Test cache |
| `docs/audits/` | Stale audit reports |
| `docs/decisions/` | UML compliance audits (outdated) |
| `docs/plan_*.md` | All execution plans |
| `docs/plan_revert_*.md` | Revert cleanup plans |
| `implementation_plan.md` | Stale backlog debugging plan |
| `tests/` | Python pipeline tests (stale) |
| `wiki/` | Stale wiki docs |
| `schema/` | Empty placeholder |
| `scripts/` | Pipeline scripts (may be stale) |
| `node_modules/` | If present |
| `.tessl-plugin/` | Plugin config |

## 3. Docs That Stay

| File | Reason |
|------|--------|
| `docs/features/` | Feature specifications |
| `docs/epics/` | Epic definitions |
| `docs/use_cases/` | Use case docs |
| `docs/architecture/` | Architecture docs |
| `docs/reviews/` | Code review docs |
| `docs/designs/` | Design documents |

## 4. Execution Steps

```bash
# Step 1: Create new repo
gh repo create gintatkinson/3dgs-phoenix --public --clone

# Step 2: Copy files (from current workspace)
cd /tmp
cp -r /Users/perkunas/jail/3dgs-002/app_flutter .
cp -r /Users/perkunas/jail/3dgs-002/cesium_native_bridge .
cp -r /Users/perkunas/jail/3dgs-002/third_party .
cp -r /Users/perkunas/jail/3dgs-002/skills .
cp -r /Users/perkunas/jail/3dgs-002/.pipeline .
cp -r /Users/perkunas/jail/3dgs-002/rules .
cp -r /Users/perkunas/jail/3dgs-002/.agents .
cp -r /Users/perkunas/jail/3dgs-002/.github .
# Docs — select subdirectories
mkdir -p docs
cp -r /Users/perkunas/jail/3dgs-002/docs/features docs/
cp -r /Users/perkunas/jail/3dgs-002/docs/epics docs/ 2>/dev/null
cp -r /Users/perkunas/jail/3dgs-002/docs/use_cases docs/ 2>/dev/null
cp -r /Users/perkunas/jail/3dgs-002/docs/architecture docs/ 2>/dev/null
cp -r /Users/perkunas/jail/3dgs-002/docs/reviews docs/ 2>/dev/null
cp -r /Users/perkunas/jail/3dgs-002/docs/designs docs/ 2>/dev/null
# Root files
cp /Users/perkunas/jail/3dgs-002/{README.md,LICENSE,requirements.txt,firebase.json,firestore.rules,.gitignore,.gitmodules,tessl.json} .

# Step 3: Init and push
cd gintatkinson/3dgs-phoenix
git init
git add -A
git commit -m "Phoenix from 3dgs-002 — source, skills, governance, zero bugs"
git push origin main

# Step 4: Verify
gh issue list --repo gintatkinson/3dgs-phoenix --limit 5 --state open
# Expected: 0
```

## 5. Post-Creation

- 0 open bugs, 0 closed bugs, 0 anything
- v2.0 skill ready to run clean-slate
- Source code unchanged — same bugs in code, clean tracker

## 6. What This Does NOT Do

- Does NOT delete or modify `gintatkinson/3dgs-002` — old repo stays as archive
- Does NOT fix any code bugs — same source, new home
- Does NOT re-run audit — that's the next step after phoenix rises
