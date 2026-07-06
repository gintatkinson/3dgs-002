# Implementation Plan — Run adversarial-code-auditor v1.4 (Memory Safety)

**Date:** 2026-07-06
**Branch:** `feat/1-3d-network-visualization`
**Skill:** `adversarial-code-auditor` v1.4
**Skill file:** [skills/adversarial-code-auditor/SKILL.md](https://github.com/gintatkinson/3dgs-002/blob/feat/1-3d-network-visualization/skills/adversarial-code-auditor/SKILL.md)
**Scope:** Run the complete audit workflow on the Memory Safety pillar across 6 source files with 11 known open issues. Produce calibrated findings, file new discoveries, add UML comments to existing issues, generate clean aggregate report.

---

## 1. Goal

Execute the v1.4 adversarial-code-auditor end-to-end on the Memory Safety risk pillar. After v1.2's failure (inflated severity, fabricated claims, zero filed issues), this run proves the fixed tool produces honest, calibrated, UML-compliant defect documentation. Output: new issues for any undiscovered defects + comments on existing issues where the audit confirms/extends them + a clean aggregate report saved to `docs/audits/`.

---

## 2. Pre-conditions

```bash
# 1. Correct branch
git branch --show-current | grep -q "feat/1-3d-network-visualization"

# 2. gh authenticated
gh auth status --repo gintatkinson/3dgs-002

# 3. v1.4 skill committed and pushable
git diff --cached -- skills/adversarial-code-auditor/SKILL.md | grep "version.*1.4"
git push --dry-run 2>&1 | grep -v "error"

# 4. All 11 target issues exist and are OPEN
for n in 74 75 76 77 84 85 87 92 93 94 199; do
  gh issue view $n --repo gintatkinson/3dgs-002 --json state --jq '.state' | grep -q OPEN || \
  echo "FAIL: Issue #$n not open"
done

# 5. All 6 target source files exist
for f in cesium_native_bridge/src/bridge.cpp \
         cesium_native_bridge/src/resource_manager.cpp \
         app_flutter/lib/domain/cesium_3d/cesium_engine.dart \
         app_flutter/lib/domain/cesium_3d/native/native_resource.dart \
         app_flutter/lib/domain/cesium_3d/virtual_camera.dart \
         app_flutter/lib/domain/cesium_3d/tile_fetcher.dart; do
  test -f "$f" || echo "FAIL: $f missing"
done

# 6. constitution.md and flutter profile readable
test -f .pipeline/constitution.md && test -f .pipeline/profiles/flutter.md
```

---

## 3. Open Questions

* **Q1:** Destination for aggregate report — `docs/audits/adversarial-audit-memory-safety-2026-07-06.md` was deleted. Replace with `docs/audits/adversarial-audit-memory-safety-2026-07-07.md` (new date) or same filename?
  * **Assumption:** Use new date `2026-07-07.md`. The old file was deleted; don't reuse the same name to avoid confusion.

* **Q2:** Should the audit also cover the test file `app_flutter/test/cesium_3d_test.dart` given issue #87 (zero coverage for CesiumEngine FFI paths)?
  * **Assumption:** Yes. Include the test file in the hit list. The Test Integrity pillar would normally cover it, but #87 is labeled `bug` and references Memory Safety concerns (untested FFI error paths). Audit it through the Memory Safety lens.

* **Q3:** Update the 4 downgraded issues (#75, #85, #93, #94) with UML diagrams?
  * **Assumption:** No. They are classified as Suggestion under v1.4. UML is only mandatory for Critical/Important. The downgrade comments already posted suffice.

---

## 4. Scoping Summary (Step 0 output)

### Target pillar: Memory Safety

### File hit list (ranked by open issue count):

| Rank | File | Open issues | Issue numbers |
|------|------|-------------|---------------|
| 1 | `cesium_native_bridge/src/bridge.cpp` | 3 | #74, #75, #76 |
| 2 | `cesium_native_bridge/src/resource_manager.cpp` | 1 | #77 |
| 3 | `app_flutter/lib/domain/cesium_3d/cesium_engine.dart` | 2 | #84, #85 |
| 4 | `app_flutter/lib/domain/cesium_3d/tile_fetcher.dart` | 1 | #92 |
| 5 | `app_flutter/lib/domain/cesium_3d/native/native_resource.dart` | 1 | #199 |
| 6 | `app_flutter/lib/domain/cesium_3d/virtual_camera.dart` | 1 | #94 (Suggestion) |
| 7 | `app_flutter/test/cesium_3d_test.dart` | 1 | #87 |

### Known issue mapping for each auditor:

| File | Known issues to pass to auditor |
|------|--------------------------------|
| bridge.cpp | #74, #75, #76 |
| resource_manager.cpp | #77 |
| cesium_engine.dart | #84, #85 |
| tile_fetcher.dart | #92 |
| native_resource.dart | #199, #136 (closed, for context) |
| virtual_camera.dart | #94, #134 (closed, for context) |
| cesium_3d_test.dart | #87 |

### Existing review docs (optional context for auditors):
- `docs/reviews/review_cpp_bridge.md` — if exists
- `docs/audits/` — prior audit findings (stale report is deleted, but context may be in issue bodies)

---

## 5. Step-by-Step Execution

### Step 1 (Audit) — Dispatch 6 auditor subagents

For each file, dispatch a fresh subagent using the Memory Safety Auditor Prompt template from the skill (lines 399-419). Fill in the template parameters:

```
Auditor. Read file: [FILE_PATH]. Also read [REVIEW_DOC_PATH] if it exists.
Pillar: Memory Safety. 8-dimension review. Weight Correctness HIGH.

KNOWN ISSUES for this file: [ISSUE_NUMBERS]. Read: gh issue view [N1 N2 N3] --repo gintatkinson/3dgs-002 --json body

Focus: double-free, UAF, dangling pointers, exception safety at extern "C", malloc/free pairing, NativeFinalizer correctness, mutex lifetime in async callbacks, string lifetime across FFI.

HARD RULES:
- Every finding MUST cite exact file:line. No line = no report.
- Before claiming NEW issue: read known issue bodies via gh. If the root cause is already described, output COMMENT_FOR_ISSUE, not a new ISSUE.
- Apply Severity Calibration rubric. Only reachable-from-current-callers is Critical. Forward-looking/future-risk is Suggestion.
- Verify facts against source. "No validation" is only true if zero checks exist. If a NaN guard exists, say so.
- Stub functions that cannot throw have no exception risk. Do not flag.
- Section 4 UML diagram is MANDATORY for every Critical and Important finding. Select diagram type from the UML Diagram Requirements table. Use file:line references from Section 3 as lifeline/transition annotations.

Produce 7-section issue bodies. Confirms/Extends -> comment. Discovered -> new issue.
Return output. PROCEED
```

**Concrete prompts per file:**

#### Subagent 1 — bridge.cpp
```
Auditor. Read file: cesium_native_bridge/src/bridge.cpp. Also read docs/reviews/review_cpp_bridge.md if it exists.
Pillar: Memory Safety. 8-dimension review. Weight Correctness HIGH.

KNOWN ISSUES for this file: #74, #75, #76. Read: gh issue view 74 75 76 --repo gintatkinson/3dgs-002 --json body

Focus: double-free, UAF, dangling pointers, exception safety at extern "C", malloc/free pairing, NativeFinalizer correctness, mutex lifetime in async callbacks, string lifetime across FFI.

HARD RULES:
- Every finding MUST cite exact file:line. No line = no report.
- Before claiming NEW issue: read known issue bodies via gh. If the root cause is already described, output COMMENT_FOR_ISSUE, not a new ISSUE.
- Apply Severity Calibration rubric. Only reachable-from-current-callers is Critical. Forward-looking/future-risk is Suggestion.
- Verify facts against source. "No validation" is only true if zero checks exist. If a NaN guard exists, say so.
- Stub functions that cannot throw have no exception risk. Do not flag.
- Section 4 UML diagram is MANDATORY for every Critical and Important finding. Select diagram type from the UML Diagram Requirements table. Use file:line references from Section 3 as lifeline/transition annotations.

Produce 7-section issue bodies. Confirms/Extends -> comment. Discovered -> new issue.
Return output. PROCEED
```

#### Subagent 2 — resource_manager.cpp
```
Auditor. Read file: cesium_native_bridge/src/resource_manager.cpp.
Pillar: Memory Safety. 8-dimension review. Weight Correctness HIGH.

KNOWN ISSUES for this file: #77. Read: gh issue view 77 --repo gintatkinson/3dgs-002 --json body

Focus: double-free, UAF, dangling pointers, exception safety at extern "C", malloc/free pairing, NativeFinalizer correctness, mutex lifetime in async callbacks, string lifetime across FFI.

HARD RULES:
- Every finding MUST cite exact file:line. No line = no report.
- Before claiming NEW issue: read known issue bodies via gh. If the root cause is already described, output COMMENT_FOR_ISSUE, not a new ISSUE.
- Apply Severity Calibration rubric. Only reachable-from-current-callers is Critical. Forward-looking/future-risk is Suggestion.
- Verify facts against source. "No validation" is only true if zero checks exist. If a NaN guard exists, say so.
- Stub functions that cannot throw have no exception risk. Do not flag.
- Section 4 UML diagram is MANDATORY for every Critical and Important finding. Select diagram type from the UML Diagram Requirements table. Use file:line references from Section 3 as lifeline/transition annotations.

Produce 7-section issue bodies. Confirms/Extends -> comment. Discovered -> new issue.
Return output. PROCEED
```

#### Subagent 3 — cesium_engine.dart
```
Auditor. Read file: app_flutter/lib/domain/cesium_3d/cesium_engine.dart.
Pillar: Memory Safety. 8-dimension review. Weight Correctness HIGH.

KNOWN ISSUES for this file: #84, #85. Read: gh issue view 84 85 --repo gintatkinson/3dgs-002 --json body

Focus: double-free, UAF, dangling pointers, exception safety at extern "C", malloc/free pairing, NativeFinalizer correctness, mutex lifetime in async callbacks, string lifetime across FFI.

HARD RULES:
- Every finding MUST cite exact file:line. No line = no report.
- Before claiming NEW issue: read known issue bodies via gh. If the root cause is already described, output COMMENT_FOR_ISSUE, not a new ISSUE.
- Apply Severity Calibration rubric. Only reachable-from-current-callers is Critical. Forward-looking/future-risk is Suggestion.
- Verify facts against source. "No validation" is only true if zero checks exist. If a NaN guard exists, say so.
- Stub functions that cannot throw have no exception risk. Do not flag.
- Section 4 UML diagram is MANDATORY for every Critical and Important finding. Select diagram type from the UML Diagram Requirements table. Use file:line references from Section 3 as lifeline/transition annotations.

Produce 7-section issue bodies. Confirms/Extends -> comment. Discovered -> new issue.
Return output. PROCEED
```

#### Subagent 4 — tile_fetcher.dart
```
Auditor. Read file: app_flutter/lib/domain/cesium_3d/tile_fetcher.dart.
Pillar: Memory Safety. 8-dimension review. Weight Correctness HIGH.

KNOWN ISSUES for this file: #92. Read: gh issue view 92 --repo gintatkinson/3dgs-002 --json body

Focus: double-free, UAF, dangling pointers, exception safety at extern "C", malloc/free pairing, NativeFinalizer correctness, mutex lifetime in async callbacks, string lifetime across FFI.

HARD RULES:
- Every finding MUST cite exact file:line. No line = no report.
- Before claiming NEW issue: read known issue bodies via gh. If the root cause is already described, output COMMENT_FOR_ISSUE, not a new ISSUE.
- Apply Severity Calibration rubric. Only reachable-from-current-callers is Critical. Forward-looking/future-risk is Suggestion.
- Verify facts against source. "No validation" is only true if zero checks exist. If a NaN guard exists, say so.
- Stub functions that cannot throw have no exception risk. Do not flag.
- Section 4 UML diagram is MANDATORY for every Critical and Important finding. Select diagram type from the UML Diagram Requirements table. Use file:line references from Section 3 as lifeline/transition annotations.

Produce 7-section issue bodies. Confirms/Extends -> comment. Discovered -> new issue.
Return output. PROCEED
```

#### Subagent 5 — native_resource.dart
```
Auditor. Read file: app_flutter/lib/domain/cesium_3d/native/native_resource.dart.
Pillar: Memory Safety. 8-dimension review. Weight Correctness HIGH.

KNOWN ISSUES for this file: #199. Also read closed issue #136 for context. Read: gh issue view 199 136 --repo gintatkinson/3dgs-002 --json body

Focus: double-free, UAF, dangling pointers, exception safety at extern "C", malloc/free pairing, NativeFinalizer correctness, mutex lifetime in async callbacks, string lifetime across FFI.

HARD RULES:
- Every finding MUST cite exact file:line. No line = no report.
- Before claiming NEW issue: read known issue bodies via gh. If the root cause is already described, output COMMENT_FOR_ISSUE, not a new ISSUE.
- Apply Severity Calibration rubric. Only reachable-from-current-callers is Critical. Forward-looking/future-risk is Suggestion.
- Verify facts against source. "No validation" is only true if zero checks exist. If a NaN guard exists, say so.
- Stub functions that cannot throw have no exception risk. Do not flag.
- Section 4 UML diagram is MANDATORY for every Critical and Important finding. Select diagram type from the UML Diagram Requirements table. Use file:line references from Section 3 as lifeline/transition annotations.

Produce 7-section issue bodies. Confirms/Extends -> comment. Discovered -> new issue.
Return output. PROCEED
```

#### Subagent 6 — virtual_camera.dart + test file
```
Auditor. Read file: app_flutter/lib/domain/cesium_3d/virtual_camera.dart. Also read app_flutter/test/cesium_3d_test.dart for context.
Pillar: Memory Safety. 8-dimension review. Weight Correctness HIGH.

KNOWN ISSUES for this file: #94. Also read closed issue #134 for context. Also review #87 (test coverage gap — read: gh issue view 87 --repo gintatkinson/3dgs-002 --json body).

Focus: double-free, UAF, dangling pointers, exception safety at extern "C", malloc/free pairing, NativeFinalizer correctness, mutex lifetime in async callbacks, string lifetime across FFI.

HARD RULES:
- Every finding MUST cite exact file:line. No line = no report.
- Before claiming NEW issue: read known issue bodies via gh. If the root cause is already described, output COMMENT_FOR_ISSUE, not a new ISSUE.
- Apply Severity Calibration rubric. Only reachable-from-current-callers is Critical. Forward-looking/future-risk is Suggestion.
- Verify facts against source. "No validation" is only true if zero checks exist. If a NaN guard exists, say so.
- Stub functions that cannot throw have no exception risk. Do not flag.
- Section 4 UML diagram is MANDATORY for every Critical and Important finding. Select diagram type from the UML Diagram Requirements table. Use file:line references from Section 3 as lifeline/transition annotations.

Produce 7-section issue bodies. Confirms/Extends -> comment. Discovered -> new issue.
Return output. PROCEED
```

**Dispatch strategy:** All 6 subagents dispatched in parallel (independent contexts, independent files). Coordinator waits for all 6 to return before proceeding to quality gate.

### Step D.1 — Coordinator Quality Gate

Collect all 6 auditor outputs. For each finding, apply the 5 checks from the skill (lines 260-264):

1. **Line citation:** Finding cites `file:line` reference.
2. **Severity rubric:** Critical = crash/leak from current callers. Forward-looking = Suggestion. Stubs-that-can't-throw = not a finding.
3. **Code exists:** The cited lines contain the claimed defect.
4. **No false claims:** "No validation" claims are accurate — no existing guards contradicted.
5. **UML diagram:** Every Critical/Important finding includes a Mermaid diagram matching the pillar→type table. No placeholder diagrams.

**Expected rejections (informed by prior manual review):**
- Any claim of "no NaN validation" in virtual_camera.dart → REJECT (guard exists at :26-33)
- Any claim of "exception propagation" in resource_manager.cpp's stub functions → REJECT (can't throw)
- Any claim of "zero test coverage" for VirtualCamera → REJECT (test file exists with NaN tests at :87-110)
- Any claim of "worker thread UAF" in bridge.cpp → REJECT (no worker threads exist)
- Any claim that classifies #75/#85/#93/#94 as Critical → REJECT (forward-looking = Suggestion per rubric)

**Expected pass (informed by prior manual review):**
- #74 UAF confirmation comment with UML → PASS
- #76 exception propagation comment with UML → PASS
- #77 signed wrap comment with UML → PASS
- #84 checkStatus leak comment with UML → PASS
- #92 LRU eviction comment with UML → PASS
- #199 finalizer leak comment with UML → PASS
- Any genuinely NEW finding (e.g., undiscovered pattern in a file) → PASS if checks pass

### Step 1.E — File passed findings

For each passed finding:
```bash
# New issues
cat > /tmp/gh_body.md << 'ENDOFFILE'
[paste ISSUE_BODY verbatim from auditor output]
ENDOFFILE
gh issue create --repo gintatkinson/3dgs-002 --title "[exact ISSUE_TITLE]" --label "bug" --body-file /tmp/gh_body.md

# Comments on existing issues
cat > /tmp/gh_comment.md << 'ENDOFFILE'
[paste COMMENT_BODY verbatim from auditor output]
ENDOFFILE
gh issue comment N --repo gintatkinson/3dgs-002 --body-file /tmp/gh_comment.md
```

Capture all issue URLs and comment references for the aggregate report.

### Step 2 — Cross-Reference Deduplication

1. Scan all filed issue bodies for the same root cause across files.
2. If duplicates found, close extras with a comment linking to the canonical issue.
3. Add cross-reference comments linking related findings (e.g., the `checkStatus` pattern in cesium_engine.dart #84 is the same root cause as the `calloc` pattern in native_resource.dart).

### Step 3 — Aggregate Risk Report

Dispatch a subagent to produce the report. Template from skill lines 303-336.

Save to: `docs/audits/adversarial-audit-memory-safety-2026-07-07.md`

### Step 4 — Back-Propagation Decision

Evaluate: does this audit expose any gap in the pipeline tooling that the existing skills cannot catch? If yes, file upstream issue on `gintatkinson/digital-pipeline-repo`.

Given that v1.4 was refined from v1.2 based on this session's discoveries, the skill itself is a back-propagation candidate.

---

## 6. Expected Output Summary

| What | Expected count |
|------|---------------|
| Audit subagents dispatched | 6 (one per file) |
| Findings passing quality gate | 6-10 (mostly comments on existing issues) |
| Findings rejected at quality gate | 0-3 (if auditors repeat v1.2 mistakes) |
| New issues filed | 0-3 (if auditors find genuinely new defects) |
| Comments on existing issues | 6-8 (one per known issue with UML + 5 Whys) |
| Aggregate report | 1 file at `docs/audits/adversarial-audit-memory-safety-2026-07-07.md` |

---

## 7. Verification Plan

### Per-step checks

| Step | Check | Expected |
|------|-------|----------|
| Step 1 | All 6 subagents returned output | 6 `ISSUE_TITLE:` / `ISSUE_BODY:` or `COMMENT_FOR_ISSUE:` blocks received |
| Step D.1 | Quality gate applied to every finding | Rejection count logged, reasons documented |
| Step 1.E | `gh issue create` / `gh issue comment` succeeded | URLs captured from stdout |
| Step 2 | No duplicate root causes remain | Dedup log complete |
| Step 3 | Report file exists and is non-empty | `wc -l docs/audits/adversarial-audit-memory-safety-2026-07-07.md` > 20 |
| Step 4 | Decision documented | "Filed upstream" or "Not applicable — skill already back-propagated" |

### Post-execution verification

```bash
# All existing issues still OPEN (audit does not change issue state)
for n in 74 75 76 77 84 85 87 92 93 94 199; do
  gh issue view $n --repo gintatkinson/3dgs-002 --json state --jq '.state' | grep -q OPEN || echo "WARN: #$n changed state"
done

# Any new issues created are OPEN
for n in [captured new issue numbers]; do
  gh issue view $n --repo gintatkinson/3dgs-002 --json state --jq '.state' | grep -q OPEN
done

# Report exists
test -f docs/audits/adversarial-audit-memory-safety-2026-07-07.md

# No findings with "no validation" claim where guards exist
# (Manual spot-check of report per-file summaries)

# Every COMMENT_FOR_ISSUE is on the correct issue
# (Manual spot-check: gh issue view N --repo gintatkinson/3dgs-002 --json comments)
```

---

## 8. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Auditor subagent repeats v1.2 inflation | Moderate | Wasted coordinator time at quality gate | Quality gate catches and rejects. Logged in report. |
| Auditor subagent hallucinates file:line numbers | Low (v1.4 rules mandate exact lines) | Bad filing | Quality gate check #3 verifies code at cited lines exists |
| `gh` rate limiting | Low (6-10 comments + 0-3 creates) | Delay | Sleep 2s between operations |
| Auditor subagent returns no findings for a file | Low | Missing coverage | Coordinator notes in report: "No findings" with file name |
| Subagent fails to complete (runtime crash) | Low-Medium | Gap in audit | Re-dispatch for that file with fresh context |
| Concurrency subagent dispatched by mistake | Low | Wrong pillar analysis | Audit scope is explicitly Memory Safety only |

---

## 9. Dependencies

```
Step 0 (scoping — this plan IS the scoping output)
        |
        v
Step 1 — Dispatch 6 auditors IN PARALLEL
   |---- Subagent 1 (bridge.cpp)
   |---- Subagent 2 (resource_manager.cpp)
   |---- Subagent 3 (cesium_engine.dart)
   |---- Subagent 4 (tile_fetcher.dart)
   |---- Subagent 5 (native_resource.dart)
   |---- Subagent 6 (virtual_camera + test)
        |
        v  [ALL 6 MUST RETURN]
Step D.1 — Coordinator quality gate
        |
        v
Step 1.E — File passed findings, log rejections
        |
        v
Step 2 — Cross-reference dedup
        |
        v
Step 3 — Aggregate report (dispatch subagent)
        |
        v
Step 4 — Back-propagation decision
```

---

## 10. What This Plan Does NOT Do

- Does NOT fix any bugs (audit only)
- Does NOT close or reopen any existing issues
- Does NOT modify any source code
- Does NOT run the Resource Lifecycle, Concurrency, or Test Integrity pillars (separate plans)
- Does NOT commit or push (aggregate report is untracked; issue operations are remote GitHub)
- Does NOT replace the need for `debug-protocol` on individual bugs
