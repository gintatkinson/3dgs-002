# Round 3 — Resource Lifecycle + Concurrency + Test Integrity Execution Plan

## Phase 0 — Pre-flight + Mine Prior Rounds

### 0.1 — File all unfiled round 2 content
Round 2 auditors produced full 8-dimension outputs. Only Critical and Important findings were filed as new issues or comments. Remaining unfiled:
- Suggestions and Nitpicks from all 6 auditors — to be filed as comments on the most relevant known issue
- Truncated A1 output (58KB saved to tool-output) — full content to be mined for additional findings
- 5 cross-cutting systemic patterns — to be filed as 5 new issues linking all affected files

### 0.2 — File cross-cutting patterns as new issues
1. **Pattern: No try/finally on calloc allocations** — affected: cesium_engine.dart, native_resource.dart, resource_manager.cpp
2. **Pattern: No exception guards on extern "C" boundaries** — affected: bridge.cpp (12 entry points), resource_manager.cpp (3 entry points)
3. **Pattern: No input validation before FFI boundary** — affected: virtual_camera.dart, cesium_engine.dart, resource_manager.cpp
4. **Pattern: Zero test coverage for FFI error paths** — affected: all 6 audited files
5. **Pattern: Raw pointer exposure enabling UAF** — affected: native_resource.dart, cesium_engine.dart

### 0.3 — Verify round 1 baseline gaps
Round 1 produced 62 findings. Most were confirmed by round 2 and filed as comments. Any round 1 finding NOT covered by a round 2 comment gets filed as a new comment on the relevant issue.

### 0.4 — Standard pre-flight
- Verify all Phase 1/2/3 target files exist
- Confirm all listed open bugs are OPEN
- Stage /tmp/audit_r3/
- Wait for PROCEED from human

---

## Phase 1 — Resource Lifecycle (GPU / Image / Memory)

### Target Issues
#141, #140, #139, #138, #135, #109, #98, #95, #88, #68, #70, #69

### File Hit List

| File | Issues |
|------|--------|
| `app_flutter/lib/features/topology/scene_3d_viewport.dart` | #141, #95, #66 |
| `app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart` | #139, #138, #135 |
| `app_flutter/lib/domain/cesium_3d/tile_fetcher.dart` | #140, #138 |
| `app_flutter/lib/features/tables/table_view_widget.dart` | #109 |
| `app_flutter/lib/features/topology/topology_map.dart` | #98 |
| `app_flutter/lib/features/layout/layout.dart` | #88, #68 |
| `app_flutter/lib/features/layout/split_workspace.dart` | #69 |
| `app_flutter/lib/core/theme/widgets/settings_panel.dart` | #70 |

### Auditor Dispatch (8 parallel)

**A1 — scene_3d_viewport.dart** — #141 (setState storms), #95 (starry loop), #66 (timer.periodic)
Pillar: Resource Lifecycle (HIGH: GC churn, repaint storms, GPU waste)
Known issues: #141, #95, #66, #65 (text painter churn)

**A2 — globe_tile_renderer.dart** — #139 (quadtree fallback), #138 (cache thrashing), #135 (ui.Image disposal)
Pillar: Resource Lifecycle (HIGH: GPU disposal, cache eviction, tile lifecycle)

**A3 — tile_fetcher.dart** — #140 (main-thread decode), #138 (cache thrashing)
Pillar: Resource Lifecycle (HIGH: image decode on wrong thread, cache pressure)

**A4 — table_view_widget.dart** — #109 (redundant repaint)
Pillar: Resource Lifecycle (HIGH: paint overhead, RenderObject count)

**A5 — topology_map.dart** — #98 (double scrollview hierarchy)
Pillar: Resource Lifecycle (HIGH: widget tree depth, gesture conflict)

**A6 — layout.dart** — #88 (redundant config loading), #68 (sync I/O on UI thread)
Pillar: Resource Lifecycle (HIGH: file I/O, config parse on main thread)

**A7 — split_workspace.dart** — #69 (zero-constraints overflow)
Pillar: Resource Lifecycle (HIGH: layout overflow, RenderFlex errors)

**A8 — settings_panel.dart** — #70 (color luminance contrast)
Pillar: Resource Lifecycle

### Output
Each auditor reads their file + existing issue bodies. Produces 7-section issue bodies. Files comments on existing issues (Confirms/Extends) and creates new issues (Discovered). Same format as Memory Safety audit.

---

## Phase 2 — Concurrency Correctness (Async Races / ViewModel State)

### Target Issues
#125, #91, #105, #104, #89, #83, #67, #66, #73, #72, #71

### File Hit List

| File | Issues |
|------|--------|
| `app_flutter/lib/domain/repository_resolver.dart` | #125 |
| `app_flutter/lib/features/properties/view_models/properties_view_model.dart` | #91 |
| `app_flutter/lib/features/tables/view_models/tables_view_model.dart` | #105 |
| `app_flutter/lib/features/tree/view_models/tree_view_model.dart` | #104 |
| `app_flutter/lib/features/layout/layout.dart` | #89 |
| `app_flutter/lib/domain/cesium_3d/virtual_camera.dart` | #83 |
| `app_flutter/lib/features/layout/breadcrumbs.dart` | #67 |
| `app_flutter/lib/features/topology/scene_3d_viewport.dart` | #66 |
| `app_flutter/lib/domain/data_sources/firebase_data_source.dart` | #73, #72 |
| `app_flutter/lib/core/background_worker.dart` | #71 |

### Auditor Dispatch (10 parallel)

Each auditor receives their file + issue bodies. Concurrency lens:
- ChangeNotifier disposal-after-notify
- Async type-loading races
- State mutation in build()
- Watch/subscription lifecycle
- Timer vs animation frame sync

### Output
7-section issue bodies. Comments on existing. New for discovered.

---

## Phase 3 — Test Integrity (Isolation / Reliability)

### Target Issues
#123, #122, #121, #120, #82, #81, #80, #79, #78, #124, #119, #118, #117, #116, #115, #114, #113

### File Hit List

| File | Issues |
|------|--------|
| `app_flutter/test/widget_test.dart` | #121, #78 |
| `app_flutter/test/layout_test.dart` | #121, #78 |
| `app_flutter/test/cesium_3d/ffi_integration_test.dart` | #120 |
| `app_flutter/test/cesium_3d_test.dart` | #82, #87 |
| `app_flutter/test/property_grid_test.dart` | #81, #80 |
| `app_flutter/test/topology/camera_reset_reproduction_test.dart` | #80 |
| `app_flutter/test/core/theme/theme_controller_test.dart` | #80 |
| `app_flutter/test/features/tables/data_table_benchmark_test.dart` | #79 |
| `app_flutter/test/topology/scroll_zoom_test.dart` | #123 |
| `app_flutter/test/topology/right_click_drag_test.dart` | #123 |
| `app_flutter/integration_test/node_iteration_test.dart` | #122 |
| `app_flutter/lib/domain/database_initializer.dart` | #124 |
| `app_flutter/lib/domain/... (dead code) ...` | #119 |
| `app_flutter/lib/... (jsonDecode cast) ...` | #118 |
| `app_flutter/lib/... (validator strings) ...` | #117 |
| `app_flutter/lib/... (regex compile) ...` | #116 |
| `app_flutter/lib/... (unique constraint) ...` | #115 |
| `app_flutter/lib/domain/... (circular deps) ...` | #114 |
| `app_flutter/lib/... (hardcoded mock) ...` | #113 |

### Auditor Dispatch (~15 parallel)

Test Integrity lens:
- FFI/DB-dependent tests (must be isolated)
- sleep/Future.delayed loops (flakiness)
- Bare assert() vs expect()
- Missing testWrappers
- Duplicated fakes/stubs
- Hardcoded paths

### Output
Same 7-section format. Comments on existing. New for discovered.

---

## Filing Procedure (All Phases)

Every auditor:
1. Reads their file(s) + existing issue bodies
2. Applies 8-dimension review through pillar lens
3. Produces 7-section issue bodies
4. Writes temp file verbatim
5. Runs gh issue create --body-file for Discovered findings
6. Runs gh issue comment --body-file for Confirms/Extends findings
7. Returns list of filed URLs

---

## Sequencing

```
PROCEED gate
  -> Phase 1 (8 auditors parallel) -> verify
  -> Phase 2 (10 auditors parallel) -> verify
  -> Phase 3 (~15 auditors parallel) -> verify
  -> Aggregate cross-pillar report
```

## Content Firewall

Coordinator: scope, dispatch, verify URLs. NEVER touches issue content. Auditors file their own findings.
