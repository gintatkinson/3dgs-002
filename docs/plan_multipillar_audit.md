# Multi-Pillar Audit Plan — adversarial-code-auditor v1.4

**Date:** 2026-07-06
**Branch:** `feat/1-3d-network-visualization`
**Skill:** `skills/adversarial-code-auditor/SKILL.md` v1.4

This plan covers all 4 risk pillars across 95 classified issues. Execution is sequential by pillar. Each pillar phase follows the same 6-step workflow from the skill: scope → dispatch → quality gate → file → dedup → report.

---

## 0. Issue Landscape

| Pillar | Issues | Already [AUDIT] tagged | Source files |
|--------|--------|----------------------|-------------|
| Memory Safety | 27 | 22 (#161-183, #198-199) | 15 |
| Resource Lifecycle | 32 | 13 (#175-178, #184-188, #194-196) | 33 |
| Concurrency | 20 | 9 (#189-197) | 24 |
| Test Integrity | 16 | 2 (#182, #198) | 36 |
| **Total** | **95** | **~40** | **~108 refs** |

15 unclassified issues (#69, #70, #83, #96, #97, #99, #101, #102, #110, #111, #112, #115, #117, #118, #119) are outside the 4 risk pillars and NOT in scope.

---

## 1. Pre-conditions (all phases)

```bash
git branch --show-current | grep -q "feat/1-3d-network-visualization"
gh auth status --repo gintatkinson/3dgs-002
grep -q "version.*1.4" skills/adversarial-code-auditor/SKILL.md
test -f .pipeline/constitution.md
test -f .pipeline/profiles/flutter.md
git diff --stat | grep -c . && echo "FAIL: dirty tree" || echo "PASS: clean"
```

---

## 2. Phase 1 — Memory Safety

### 2.1 Scope

27 issues across 6 core source files + 2 headers.

**File hit list:**

| File | Known issues | Expected output |
|------|-------------|-----------------|
| `bridge.cpp` | #74, #75, #76, #93, #94, #161, #162, #164 | Comment on existing AUDITs, confirm #74/#76 |
| `bridge.h` | #163 | Comment on #163 |
| `resource_manager.cpp` | #77, #165, #166, #167, #168 | Comment on existing AUDITs |
| `cesium_engine.dart` | #84, #85, #169, #170, #171 | Comment on existing AUDITs |
| `bridge_bindings.dart` | #170 (shared) | Part of cesium_engine audit |
| `native_resource.dart` | #172, #183, #199 | Comment on existing AUDITs |
| `virtual_camera.dart` | #173, #174, #181 (shared) | Comment on existing AUDITs |
| `tile_fetcher.dart` | #92 | Comment on #92 |

### 2.2 Auditor Dispatch (8 subagents)

Subagents A1-A6 use the detailed prompts from [docs/plan_run_audit_memory_safety.md](https://github.com/gintatkinson/3dgs-002/blob/feat/1-3d-network-visualization/docs/plan_run_audit_memory_safety.md) (the reverted commit content). Additional subagents:

**A7 — bridge.h (#163 only)**
```
Auditor. Read file: cesium_native_bridge/src/bridge.h.
Pillar: Memory Safety. 8-dimension review.

KNOWN ISSUES: #163. gh issue view 163 --repo gintatkinson/3dgs-002 --json body

Focus: type-level distinction between error codes and valid handles in int32_t value space.

HARD RULES: cite file:line, verify against source, UML mandatory for Critical/Important.

Do NOT modify files. Do NOT run gh. Return output. PROCEED
```

**A8 — bridge_bindings.dart (#170 shared)**
```
Auditor. Read file: app_flutter/lib/domain/cesium_3d/native/bridge_bindings.dart.
Pillar: Memory Safety.

KNOWN ISSUES: #170. gh issue view 170 --repo gintatkinson/3dgs-002 --json body

Focus: DynamicLibrary singleton safety across Flutter isolates.

HARD RULES: cite file:line, verify against source, UML mandatory for Critical/Important.

Do NOT modify files. Do NOT run gh. Return output. PROCEED
```

### 2.3 Quality Gate → File → Dedup → Report

Same workflow as detailed in the reverted plan. Aggregate report: `docs/audits/adversarial-audit-memory-safety-2026-07-06.md`

---

## 3. Phase 2 — Resource Lifecycle

### 3.1 Scope

32 issues. Top files by density: globe_tile_renderer.dart (6), tile_fetcher.dart (5), scene_3d_viewport.dart (5), layout.dart (4), firebase_data_source.dart (4).

### 3.2 Auditor Dispatch (10 subagents)

**B1 — globe_tile_renderer.dart (#135, #137, #139, #184, #186, #187)**
```
Auditor. Read file: app_flutter/lib/features/topology/globe_tile_renderer.dart.
Pillar: Resource Lifecycle. 8-dimension review. Weight Correctness HIGH.

KNOWN ISSUES: #135, #137, #139, #184, #186, #187.
gh issue view 135 137 139 184 186 187 --repo gintatkinson/3dgs-002 --json body

Also read: .pipeline/constitution.md, .pipeline/profiles/flutter.md

FOCUS:
- Missing ui.Image disposal (#135)
- Tile cache capacity thrashing (#138)
- Hierarchical quadtree fallback (#139)
- _pendingFetches timeout (#187)
- Stale imagery after provider switch (#186)
- Missing dispose from Scene3DViewport parent (#184)

HARD RULES: Every finding cites file:line. Before claiming NEW: read known issue bodies. Apply Severity Calibration rubric — only current-caller-reachable is Critical. Forward-looking = Suggestion. Section 4 UML mandatory for Critical/Important (sequenceDiagram for leak/resource, stateDiagram-v2 for cache). Verify facts against source.

Produce 7-section issue bodies. Confirms/Extends -> comment. Discovered -> new issue.
Do NOT modify files. Do NOT run gh. Return output. PROCEED
```

**B2 — scene_3d_viewport.dart (#95, #137, #141, #184, #185)**
```
Auditor. Read file: app_flutter/lib/features/topology/scene_3d_viewport.dart.
Pillar: Resource Lifecycle.

KNOWN ISSUES: #95, #137, #141, #184, #185. Read via gh issue view.
Read: .pipeline/constitution.md, .pipeline/profiles/flutter.md

FOCUS:
- BackdropFilter GPU overdraw (#185)
- Unthrottled repaint cycles / setState storms (#141)
- Missing dispose on GlobeTileRenderer, TileFetcher (#184)
- Visual jank (#137)
- Hardcoded starry background painter loop (#95)

HARD RULES: cite file:line, verify against source, UML mandatory.
Do NOT modify files. Do NOT run gh. Return output. PROCEED
```

**B3 — tile_fetcher.dart (#92, #140, #175, #176, #177, #178)**
```
Auditor. Read file: app_flutter/lib/domain/cesium_3d/tile_fetcher.dart.
Pillar: Resource Lifecycle.

KNOWN ISSUES: #92, #140, #175, #176, #177, #178. Read via gh issue view.
Read: .pipeline/constitution.md, .pipeline/profiles/flutter.md

FOCUS:
- LRU eviction correctness (#92)
- Main-thread image decoding (#140)
- Unbounded response accumulation / OOM (#175)
- Missing HTTP read timeout (#176)
- Missing dispose / HttpClient not closed (#177)
- Cache clear race with in-flight fetches (#178)

HARD RULES: cite file:line, verify against source, UML mandatory.
Do NOT modify files. Do NOT run gh. Return output. PROCEED
```

**B4 — layout.dart (#68, #88, #188, #194)**
```
Auditor. Read file: app_flutter/lib/features/layout/layout.dart.
Pillar: Resource Lifecycle.

KNOWN ISSUES: #68, #88, #188, #194. Read via gh issue view.
Read: .pipeline/constitution.md, .pipeline/profiles/flutter.md

FOCUS:
- Sync disk I/O on UI thread (#68, #188)
- Redundant config loading (#88)
- Async init silent failure / infinite spinner (#194)

HARD RULES: cite file:line, verify against source, UML mandatory.
Do NOT modify files. Do NOT run gh. Return output. PROCEED
```

**B5 — firebase_data_source.dart (#73, #195, #196)**
```
Auditor. Read file: app_flutter/lib/data/firebase_data_source.dart.
Pillar: Resource Lifecycle.

KNOWN ISSUES: #73, #195, #196. Read via gh issue view.
Read: .pipeline/constitution.md, .pipeline/profiles/flutter.md

FOCUS:
- Redundant network scans (#73)
- Cache stampede / concurrent discoverTypes (#195 — overlaps Concurrency)
- Stale schema cache (#196)

HARD RULES: cite file:line, verify against source, UML mandatory.
Do NOT modify files. Do NOT run gh. Return output. PROCEED
```

**B6 — background_worker.dart (#71, #197)**
```
Auditor. Read file: app_flutter/lib/data/background_worker.dart.
Pillar: Resource Lifecycle.

KNOWN ISSUES: #71, #197. Read via gh issue view.
Read: .pipeline/constitution.md, .pipeline/profiles/flutter.md

FOCUS:
- UI thread blockage on isolate failure (#71)
- No cancellation of in-flight isolates (#197 — overlaps Concurrency)

HARD RULES: cite file:line, verify against source, UML mandatory.
Do NOT modify files. Do NOT run gh. Return output. PROCEED
```

**B7 — table_view_widget.dart (#108, #109)**
```
Auditor. Read file: app_flutter/lib/features/tables/table_view_widget.dart.
Pillar: Resource Lifecycle.

KNOWN ISSUES: #108, #109. Read via gh issue view.

FOCUS: Heavy date parsing in build (#108), redundant repaint boundaries (#109)
HARD RULES: cite file:line, verify against source, UML mandatory.
Do NOT modify files. Do NOT run gh. Return output. PROCEED
```

**B8 — tree_view_model.dart (#107)**
```
Auditor. Read file: app_flutter/lib/features/tree/view_models/tree_view_model.dart.
Pillar: Resource Lifecycle.

KNOWN ISSUES: #107. Read via gh issue view.

FOCUS: GlobalKey allocation performance (#107)
HARD RULES: cite file:line, verify against source.
Do NOT modify files. Do NOT run gh. Return output. PROCEED
```

**B9 — layout_config_service.dart (#90)**
```
Auditor. Read file: app_flutter/lib/core/layout_config_service.dart.
Pillar: Resource Lifecycle.

KNOWN ISSUES: #90. Read via gh issue view.

FOCUS: Fragile map type casting (#90)
HARD RULES: cite file:line, verify against source.
Do NOT modify files. Do NOT run gh. Return output. PROCEED
```

**B10 — topology_map.dart, topographical_view.dart, repository_resolver.dart, instance_record.dart (#98, #125, #116)**
```
Auditor. Read files:
  app_flutter/lib/features/topology/topology_map.dart (#98)
  app_flutter/lib/domain/repository_resolver.dart (#125)
  app_flutter/lib/domain/instance_record.dart (#116)

Pillar: Resource Lifecycle.

KNOWN ISSUES: #98, #125, #116. Read via gh issue view.
Read: .pipeline/constitution.md, .pipeline/profiles/flutter.md

FOCUS: Double scrollview panning (#98), swallowed DB exceptions (#125), regex re-compilation hotspot (#116)

HARD RULES: cite file:line for every finding, verify against source, UML for Critical/Important.
Do NOT modify files. Do NOT run gh. Return output. PROCEED
```

### 3.3 Quality Gate

Same 5 checks. Expected rejections: any claim of a resource leak where dispose IS present, any GPU overdraw claim without line-level evidence of BackdropFilter usage.

### 3.4 Filing → Dedup → Report

Report: `docs/audits/adversarial-audit-resource-lifecycle-2026-07-06.md`

---

## 4. Phase 3 — Concurrency

### 4.1 Scope

20 issues. Top files: firebase_data_source.dart (3), tables_view_model.dart (3), tabbed_container.dart (2), breadcrumbs.dart (2), repository_resolver.dart (2).

### 4.2 Auditor Dispatch (9 subagents)

**C1 — tables_view_model.dart (#105, #191, #192)**
```
Auditor. Read file: app_flutter/lib/features/tables/view_models/tables_view_model.dart.
Pillar: Concurrency Correctness. 8-dimension review. Weight Correctness HIGH.

KNOWN ISSUES: #105, #191, #192. gh issue view 105 191 192 --repo gintatkinson/3dgs-002 --json body
Read: .pipeline/constitution.md, .pipeline/profiles/flutter.md

FOCUS:
- StateError on watch subscription (#105)
- Disposal race: stream events between _disposed and cancel() (#191)
- Tab-lifecycle race: subscription before tabs populated (#192)

HARD RULES: Every finding cites file:line. Critical = reachable from current callers (post-disposal notification IS reachable). Forward-looking = Suggestion. Section 4 UML mandatory for Critical/Important (sequenceDiagram for disposal races). Verify facts.

Do NOT modify files. Do NOT run gh. Return output. PROCEED
```

**C2 — firebase_data_source.dart (#72, #195)**
```
Auditor. Read file: app_flutter/lib/data/firebase_data_source.dart.
Pillar: Concurrency Correctness.

KNOWN ISSUES: #72, #195. Read via gh issue view.
Read: .pipeline/constitution.md, .pipeline/profiles/flutter.md

FOCUS: Local-only stream broadcasts (#72), cache stampede (#195)
HARD RULES: cite file:line, verify, UML mandatory. Do NOT modify/gh. PROCEED
```

**C3 — tabbed_container.dart (#106)**
```
Auditor. Read file: app_flutter/lib/features/layout/tabbed_container.dart.
Pillar: Concurrency Correctness.

KNOWN ISSUES: #106. Read via gh issue view.
FOCUS: Multi-tab rendering and keep-alive bug (#106)
HARD RULES: cite file:line, verify, UML mandatory. PROCEED
```

**C4 — breadcrumbs.dart (#67, #100)**
```
Auditor. Read file: app_flutter/lib/features/layout/breadcrumbs.dart.
Pillar: Concurrency Correctness.

KNOWN ISSUES: #67, #100. Read via gh issue view.
FOCUS: RangeError on empty tree (#67), sticky expanded ellipsis state (#100)
HARD RULES: cite file:line, verify, UML mandatory. PROCEED
```

**C5 — repository_resolver.dart (#189, #190)**
```
Auditor. Read file: app_flutter/lib/domain/repository_resolver.dart.
Pillar: Concurrency Correctness.

KNOWN ISSUES: #189, #190. Read via gh issue view.
FOCUS: Concurrent resolve() race (#189), TOCTOU dbFile.exists (#190)
HARD RULES: cite file:line, verify, UML mandatory. PROCEED
```

**C6 — tree_view_model.dart (#104, #193)**
```
Auditor. Read file: app_flutter/lib/features/tree/view_models/tree_view_model.dart.
Pillar: Concurrency Correctness.

KNOWN ISSUES: #104, #193. Read via gh issue view.
FOCUS: Global fallback state mutation (#104), expandNode re-entrancy (#193)
HARD RULES: cite file:line, verify, UML mandatory. PROCEED
```

**C7 — properties_view_model.dart (#91)**
```
Auditor. Read file: app_flutter/lib/features/properties/view_models/properties_view_model.dart.
Pillar: Concurrency Correctness.

KNOWN ISSUES: #91. Read via gh issue view.
FOCUS: Async race on concurrent type loading (#91)
HARD RULES: cite file:line, verify, UML mandatory. PROCEED
```

**C8 — app.dart (#103)**
```
Auditor. Read file: app_flutter/lib/app/app.dart.
Pillar: Concurrency Correctness.

KNOWN ISSUES: #103. Read via gh issue view.
FOCUS: Hardcoded initial active view blocks fallbacks (#103)
HARD RULES: cite file:line, verify, UML mandatory. PROCEED
```

**C9 — scene_3d_viewport.dart (#66) + layout.dart (#89) + background_worker.dart (#197)**
```
Auditor. Read files:
  app_flutter/lib/features/topology/scene_3d_viewport.dart (#66)
  app_flutter/lib/features/layout/layout.dart (#89)
  app_flutter/lib/data/background_worker.dart (#197)

Pillar: Concurrency Correctness.

KNOWN ISSUES: #66, #89, #197. Read via gh issue view.

FOCUS:
- Unsynchronized Timer.periodic frame updates (#66)
- External view updates out of sync with sidebar (#89)
- No isolate cancellation (#197)

HARD RULES: cite file:line for every finding, verify against source, UML for Critical/Important.
Do NOT modify files. Do NOT run gh. Return output. PROCEED
```

### 4.3 Quality Gate → File → Dedup → Report

Report: `docs/audits/adversarial-audit-concurrency-2026-07-06.md`

---

## 5. Phase 4 — Test Integrity

### 5.1 Scope

16 issues. Files by density: layout_test.dart (2), widget_test.dart (2), ffi_integration_test.dart (2), cesium_3d_test.dart (2).

### 5.2 Auditor Dispatch (6 subagents)

**D1 — cesium_3d_test.dart (#82, #87)**
```
Auditor. Read file: app_flutter/test/cesium_3d_test.dart.
Pillar: Test Integrity. 8-dimension review. Weight Correctness HIGH.

KNOWN ISSUES: #82, #87. gh issue view 82 87 --repo gintatkinson/3dgs-002 --json body
Read: .pipeline/constitution.md, .pipeline/profiles/flutter.md (testing mandates: flutter_test framework, testWidgets vs test)

FOCUS:
- Stateful widget stub execution (#82)
- Zero test coverage for CesiumEngine FFI paths (#87)

HARD RULES: Every finding cites file:line. Apply Severity Calibration — missing test coverage is Suggestion, not Critical. Section 4 UML mandatory for Critical/Important (classDiagram for missing mock/dependency). Verify facts — if test exists, acknowledge it.

Do NOT modify files. Do NOT run gh. Return output. PROCEED
```

**D2 — ffi_integration_test.dart (#60, #120, #198)**
```
Auditor. Read file: app_flutter/test/ffi_integration_test.dart.
Pillar: Test Integrity.

KNOWN ISSUES: #60, #120, #198. Read via gh issue view.

FOCUS: Platform init crashes (#60), bare asserts (#120), no try/finally on calloc (#198)
HARD RULES: cite file:line, verify, UML. PROCEED
```

**D3 — layout_test.dart + widget_test.dart (#78, #121)**
```
Auditor. Read files: app_flutter/test/layout_test.dart, app_flutter/test/widget_test.dart.
Pillar: Test Integrity.

KNOWN ISSUES: #78, #121. Read via gh issue view.

FOCUS: Sleep loops causing flakiness (#78), non-isolated DB FFI dependency (#121)
HARD RULES: cite file:line, verify, UML. PROCEED
```

**D4 — property_grid_test.dart + camera_reset_reproduction_test.dart + theme_controller_test.dart (#80, #81)**
```
Auditor. Read files:
  app_flutter/test/property_grid_test.dart
  app_flutter/test/camera_reset_reproduction_test.dart
  app_flutter/test/theme_controller_test.dart

Pillar: Test Integrity.

KNOWN ISSUES: #80, #81. Read via gh issue view.

FOCUS: Duplicated FakeThemeService (#80), brittle widget tree traversal (#81)
HARD RULES: cite file:line, verify, UML. PROCEED
```

**D5 — data_table_benchmark_test.dart (#79) + node_iteration_test.dart (#122) + scroll_zoom_test.dart (#123)**
```
Auditor. Read files:
  app_flutter/test/data_table_benchmark_test.dart
  app_flutter/test/node_iteration_test.dart
  app_flutter/test/scroll_zoom_test.dart

Pillar: Test Integrity.

KNOWN ISSUES: #79, #122, #123. Read via gh issue view.

FOCUS: Flaky stopwatch assertions (#79), untracked root files (#122), 'as dynamic' casting (#123)
HARD RULES: cite file:line, verify, UML. PROCEED
```

**D6 — database_initializer.dart + sqlite_data_source.dart + data_source.dart + icon_mapper.dart (#113, #114, #124)**
```
Auditor. Read files:
  app_flutter/lib/domain/database_initializer.dart
  app_flutter/lib/data/sqlite_data_source.dart
  app_flutter/lib/domain/data_source.dart
  app_flutter/lib/features/properties/icon_mapper.dart

Pillar: Test Integrity.

KNOWN ISSUES: #113, #114, #124. Read via gh issue view.

FOCUS: Hardcoded mock data in SQLite queries (#113), circular dependencies (#114), top-level main() in library (#124)
HARD RULES: cite file:line, verify, UML. PROCEED
```

### 5.3 Quality Gate → File → Dedup → Report

Report: `docs/audits/adversarial-audit-test-integrity-2026-07-06.md`

---

## 6. Execution Order & Dependencies

```
Phase 1: Memory Safety  ──┐
                          │
Phase 2: Resource Lifecycle│── Sequential (no cross-pillar file overlap)
                          │
Phase 3: Concurrency      │
                          │
Phase 4: Test Integrity  ──┘
```

Each phase is independent — no phase needs output from another. Sequential execution prevents context overload (30+ subagents in parallel is unmanageable). Within each phase, all subagents dispatch in parallel, coordinator waits for all, then quality gates and files.

**Total subagents:** 8 + 10 + 9 + 6 = 33

---

## 7. Cross-Pillar Dedup (after all 4 phases)

After all 4 phases complete, scan all filed issues for:
- Same root cause filed in different pillars (e.g., a missing dispose flagged as both Resource Lifecycle and Memory Safety)
- Cross-cutting patterns that span pillars (#179-183 are pre-identified cross-cutting issues)
- Close extras, link canonical issues

---

## 8. Mega-Report (after all 4 phases)

Dispatch one subagent to merge the 4 pillar reports into a single summary:

```markdown
# Adversarial Audit — All Pillars — 2026-07-06

## Scope
- 95 issues classified, 4 pillars, 33 subagents, ~50 unique files

## Phase Summaries
| Pillar | Files | Issues | New | Comments | Critical | Important | Suggestion |
|--------|-------|--------|-----|----------|----------|-----------|------------|
| Memory Safety | 8 | 27 | X | Y | Z | ... | ... |
| Resource Lifecycle | 10 | 32 | ... | ... | ... | ... | ... |
| Concurrency | 9 | 20 | ... | ... | ... | ... | ... |
| Test Integrity | 6 | 16 | ... | ... | ... | ... | ... |

## Cross-Cutting Patterns (from Step 2 dedup)
[Patterns, canonical issues, files affected]

## Overall Remediation Priority
[Highest-priority across all pillars]

## Unclassified Issues (out of scope)
15 issues: #69, #70, #83, #96, #97, #99, #101, #102, #110, #111, #112, #115, #117, #118, #119
```

Save to: `docs/audits/adversarial-audit-all-pillars-2026-07-06.md`

---

## 9. File Manifest

### Audit reports created

| File | Phase |
|------|-------|
| `docs/audits/adversarial-audit-memory-safety-2026-07-06.md` | 1 |
| `docs/audits/adversarial-audit-resource-lifecycle-2026-07-06.md` | 2 |
| `docs/audits/adversarial-audit-concurrency-2026-07-06.md` | 3 |
| `docs/audits/adversarial-audit-test-integrity-2026-07-06.md` | 4 |
| `docs/audits/adversarial-audit-all-pillars-2026-07-06.md` | Post-phase |

### Temp files

| File | Purpose |
|------|---------|
| `/tmp/audit_output_*.txt` | Raw auditor output per subagent |
| `/tmp/gh_body.md` | Temp issue body for gh create |
| `/tmp/gh_comment.md` | Temp comment body for gh comment |
| `/tmp/rejection_log.txt` | Quality gate rejections |

---

## 10. Risk Assessment

| Risk | Mitigation |
|------|-----------|
| 33 subagents is a lot — some will fail/timeout | Re-dispatch individual failed subagents. Phased execution means 8-10 per phase, not 33 at once |
| gh rate limiting (~60+ comments) | Sleep 2s between operations. Spread across 4 phases |
| Auditor inflates severity despite v1.4 rules | Quality gate catches and rejects. Separate rejection log |
| Cross-pillar duplicate findings | Post-phase dedup pass catches extras |
| Phase takes too long (user patience) | Each phase can be stopped and resumed. Reports are independent |

---

## 11. What This Plan Does NOT Do

- Does NOT fix any bugs
- Does NOT modify any source code
- Does NOT close any existing issues (except dedup extras)
- Does NOT cover 15 unclassified issues (UI/visual/animation — outside risk pillars)
- Does NOT commit or push (reports are added to git only if review approves)
- Does NOT replace debug-protocol for individual bug fixing
