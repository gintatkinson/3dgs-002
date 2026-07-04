# Agent Handoff Document — 3D Geospatial Engine

**Date:** 2026-07-04
**Project:** 3dgs-002 (Platform Console — Flutter Desktop)
**Branch:** `feat/1-3d-network-visualization`

---

## 1. Project Goal

Replace hardcoded geography in the 3D globe with cesium-native WGS84 ECEF transforms and add HTTP map tile imagery overlays. Match capabilities of reference app [Cognition-UI-tsx](https://github.com/gintatkinson/Cognition-UI-tsx).

---

## 2. Current State

### Working
- cesium-native C++ library cloned as submodule (`third_party/cesium-native/`)
- C ABI bridge compiled (`cesium_native_bridge/`) — 17 exported functions, builds to `libcesium_native_bridge.dylib` (70KB arm64)
- Dart FFI bindings complete (`app_flutter/lib/domain/cesium_3d/native/bridge_bindings.dart`)
- `CesiumEngine` Dart wrapper with `cartographicToEcef()`, `ecefToCartographic()` — verified working (exact decimal precision roundtrip)
- `CameraController` class with `pan()`, `tilt()`, `rotateHeading()`, `zoom()`, `keyboardTilt()`, `keyboardRotate()` — constants extracted, no magic numbers
- `VirtualCamera` has value-based `operator ==` and `hashCode`
- `TopographicalView` has camera caching (`_cachedCamera`, `_resolveCamera()`)
- `GlobeTileRenderer` + `TileFetcher` with 4 providers (OSM, ArcGIS, CARTO Dark/Light), LRU cache, compile-time disable via `--dart-define=MAP_IMAGERY_ENABLED=false`
- `Scene3DViewport` uses global pointer route (`GestureBinding.instance.pointerRouter`) to receive drag events in integration tests
- No auto-rotate (removed), no `SingleTickerProviderStateMixin`, no `AnimatedBuilder`
- All hardcoded landmass polygons, city markers, road networks removed — replaced with procedural latitude climate bands
- `flutter analyze`: 0 errors on new code (pre-existing warnings in `cesium_3d_native.dart` stub, `error_handler.dart` docs, `analysis_options.yaml`)
- `flutter test`: 135/135 pass
- `flutter build macos --release`: succeeds (182.5MB .app)

### Unknown state (need verification)
- The global pointer route fix may only work in the E2E test, not in the real macOS app
- Subagent fixes have repeatedly touched the same file; code may have regressions

---

## 3. Known Bugs (9 open)

### #50 — Critical: Camera resets on any parent rebuild
**Root cause:** `_LayoutState._updateCurrentViewFromLayout()` (layout.dart:315-321) silently mutates `_currentView` when `widget.activeView == null` and `TreeViewModel` notifies. Next `setState()` rebuild creates fresh camera from topology coordinates, discarding user pan/zoom.

**Trigger paths:**
- TreeViewModel notifies → `_onTreeViewModelChanged` → `setState`
- PropertiesViewModel notifies → `setState`
- Property data stream → `setState`
- BackgroundWorker → `setState`

**Evidence:** Investigation confirmed camera caching in `_resolveCamera()` is logically correct, but `_updateCurrentViewFromLayout` overrides cache key.

### #41 — Globe drag doesn't change camera position
**Symptom:** Camera Stats HUD updates lat/lng during drag, but globe visual doesn't change in real app. E2E test passes (isolated environment), real app doesn't.

### #42 — Scroll zoom doesn't change altitude
**Symptom:** Same pattern — HUD updates, globe visual frozen.

### #43 — Arrow keys navigate tree instead of globe
**Symptom:** Up/down arrows intercepted by ancestor scrollable. Left/right work.

### #44 — HUD shows stale values
**Symptom:** Camera Stats may reset to initial values after GUI interaction.

### #46–#49 — Navigation modifier controls
Shift+drag tilt, right-click drag, Ctrl/Cmd drag, double-click fly-to — all broken in real app.

---

## 4. Architecture

### Directory layout
```
app_flutter/
├── lib/
│   ├── domain/cesium_3d/
│   │   ├── camera_controller.dart      # Input → camera state
│   │   ├── cesium_engine.dart          # FFI → cesium-native
│   │   ├── globe_tile_renderer.dart    # HTTP tile imagery
│   │   ├── tile_fetcher.dart           # Tile HTTP client + cache
│   │   ├── virtual_camera.dart         # 6-DOF camera data class
│   │   ├── projected_point.dart        # Screen projection result
│   │   └── native/
│   │       ├── bridge_bindings.dart    # Dart FFI signatures
│   │       ├── error_handler.dart      # C status → Dart exceptions
│   │       └── native_resource.dart    # RAII native memory
│   ├── features/topology/
│   │   ├── scene_3d_viewport.dart      # 3D globe widget + painter (~1400 lines)
│   │   ├── topographical_view.dart     # 2D/3D toggle + breadcrumbs
│   │   └── topology_map.dart           # 2D canvas topology map
│   ├── features/layout/
│   │   └── layout.dart                 # Root layout, tree, property grid
│   └── core/
│       └── app_config.dart             # Compile-time flags
├── test/
│   └── cesium_3d/
│       ├── ffi_integration_test.dart    # FFI roundtrip tests
│       ├── camera_controller_test.dart  # CameraController unit tests
│       └── tile_fetcher_test.dart       # Tile fetcher + LRU cache tests
├── integration_test/
│   ├── app_e2e_test.dart               # Existing property grid E2E
│   └── globe_camera_drag_test.dart     # Globe drag E2E (passes but misleading)
├── shaders/                            # (empty — shader pipeline not viable)
└── build/macos/Build/Products/Release/
    └── app_flutter.app                  # Release build output
cesium_native_bridge/
├── CMakeLists.txt                      # Builds shared dylib
├── include/bridge.h                    # C ABI header (17 functions)
└── src/                                # C++ implementations
third_party/
└── cesium-native/                      # Git submodule
```

### Widget hierarchy (globe branch)
```
Layout (_LayoutState)
  └── TopographicalView
        └── Scene3DViewport (_Scene3DViewportState)
              ├── Focus (globeFocusNode)
              │   └── Listener (pointer route for drag)
              │       └── GestureDetector (onPanUpdate, onDoubleTap, onScaleUpdate)
              │           └── CustomPaint (Scene3DViewportPainter)
              ├── Positioned [Camera Stats HUD]
              └── Positioned [Config Panel — styles, toggles, reset]
```

### Data flow (user drag)
```
User drag → global pointer route → _cameraController.pan()
  → _cameraController._camera = new VirtualCamera()
  → setState() called by pointer route
  → build() → CustomPaint with new camera → shouldRepaint
```
**But:** parent `_LayoutState` rebuilds → `TopographicalView.build()` → `_resolveCamera()` may create fresh camera → `Scene3DViewport.didUpdateWidget` resets `_cameraController`

---

## 5. What Was Tried and Failed

| Attempt | Why Failed |
|---|---|
| Fix drag in onPanUpdate with setState | AnimatedBuilder gated rendering on animation ticks — camera frozen when auto-rotate off |
| Remove AnimatedBuilder | Camera still didn't update — unknown why in real app (E2E test passed) |
| Global modifier tracking with HardwareKeyboard | Lost focus when globe not clicked — modifiers pressed before click discarded |
| VirtualCamera value equality | Fixed identity comparison but didn't fix root cause (parent rebuild) |
| Camera caching in TopographicalView | Correct logically, but `_updateCurrentViewFromLayout` invalides cache key |
| Global pointer route for drag | Works in test, unknown if works in real macOS app |
| E2E test (globe_camera_drag_test.dart) | Passes because Scene3DViewport tested in isolation — no parent Layout to trigger camera reset |

---

## 6. Environment

```
Flutter 3.44.0 (stable, 2026-05-15)
Dart 3.12.0
macOS arm64 (Apple Silicon)
Xcode 21.0.0
cmake 4.3.4 (via Homebrew)
Homebrew 6.0.3
```

### Dependencies (pubspec.yaml)
- sqflite_common_ffi, path_provider, provider, flex_color_scheme, shared_preferences
- firebase_core, firebase_auth, cloud_firestore (available but not required for 3D globe)
- ffi (for cesium-native bridge)
- NO: webview_flutter (rejected — web not allowed)
- NO: flutter_gpu / dart:gpu (experimental, missing in 3.44.0 — Impeller shader pipeline not viable)

### Compile-time flags
- `--dart-define=DATA_SOURCE=sqlite|firebase` — select data backend (default: sqlite)
- `--dart-define=MAP_IMAGERY_ENABLED=false` — disable HTTP tile fetching (default: true)

---

## 7. Key Constraints

1. **No webview** — Cesium.js via WebView rejected. Must use cesium-native FFI.
2. **No Java** — Not applicable (Dart/Flutter project).
3. **No HTTP** — Only allowed for map imagery tiles. Must be securely disableable.
4. **No Impeller shaders** — `dart:gpu`/`flutter_gpu` not available in Flutter 3.44.0. Canvas-based rendering only.
5. **macOS only** — Primary target. Linux/Windows secondary (build verification only).
6. **TDD mandated** — RED → GREEN → REFACTOR cycle. Adversarial validation: Writer + Auditor subagents.
7. **No coordinator file-writing** — Coordinator only dispatches and verifies. Subagents write code.
8. **PROCEED required** — User must explicitly type PROCEED for any modifying action.

---

## 8. Immediate Next Steps

1. **Fix #50 first** — camera reset on parent rebuild is the root cause blocking all other fixes. Without this, no other fix will survive in the real app.
2. **Verify the global pointer route** actually dispatches drag events in the real macOS app (not just in E2E test). If not, switch to `Listener.onPointerMove` directly.
3. **Fix #41** — make drag actually change the globe visual (builds on #50 fix).
4. **Fix #42** — scroll zoom (same pipeline, should work once #50/#41 are fixed).
5. **Fix #43–#49** — modifier keys, arrow keys, double-click (lower priority, blocked by #50).

### What NOT to do
- Do NOT write more isolated E2E tests that pass but don't catch real bugs
- Do NOT add new features or abstractions
- Do NOT touch shaders/, Impeller, or GPU pipeline
- Do NOT refactor working code (camera_controller, tile_fetcher, globe_tile_renderer are fine)
- Do NOT delete the hardcoded landmass removal — that was correct

---

## 9. Build & Test Commands

```bash
# Full test suite
cd app_flutter && flutter test

# Integration test (macOS only, slow — builds app)
flutter test -d macos integration_test/globe_camera_drag_test.dart

# Static analysis
flutter analyze

# Release build
flutter build macos --release

# Launch
open build/macos/Build/Products/Release/app_flutter.app

# Clean rebuild (if stale artifacts suspected)
flutter clean && flutter pub get && flutter build macos --release

# FFI integration test (requires compiled dylib)
cd app_flutter && dart --packages=.dart_tool/package_config.json test/cesium_3d/ffi_integration_test.dart
```

## 10. GitHub Issues

- All bugs: `gh issue list --label bug`
- All features: `gh issue list --label feature`
- Issue #50 is the critical root cause
- Issues #8–#40 are shader-pipeline features — dead/invalid on Flutter 3.44.0
