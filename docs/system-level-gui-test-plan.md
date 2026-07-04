# System-Level GUI Test Plan — 3D Geospatial Engine

**Date:** 2026-07-04
**Project:** 3dgs-002
**Status:** Draft — pending `PROCEED` for implementation

---

## Rules Compliance

| Rule | How enforced |
|------|-------------|
| `tdd-mandate.md` | Each bug: write failing integration test first (RED), confirm failure with raw output, then fix (GREEN), confirm pass with raw output |
| `serial-execution.md` | One bug at a time. Bug #50 first. No starting next until current verified, committed, closed |
| `verification-required.md` | Raw `flutter test` output pasted at every RED and GREEN step |
| `user-authorization-lock.md` | Each modifying action (write file, edit file, git commit, gh close) requires user `PROCEED` |
| `constitution-first.md` | [.pipeline/constitution.md](file:///Users/perkunas/jail/3dgs-002/.pipeline/constitution.md) is active in the repository and governs project-wide coding standards. |
| `tracker-source-of-truth.md` | `gh issue view <N>` before working on any issue; `gh issue close` only after GREEN proof |
| `no-browser-automation.md` | All tests use `WidgetTester` / `testWidgets` — no headless browser, no Playwright |
| `platform-independence.md` | N/A — widget tests verify rendering behaviors across target platforms |

---

## Test Infrastructure

All tests are verified under `test/cesium_3d/` as widget tests targeting the geospatial viewport:

```dart
testWidgets('...', (WidgetTester tester) async {
  // 1. Render Scene3DViewport with a defined virtual camera
  // 2. Verify initial HUD coordinates on screen (matching "Latitude:" / "Longitude:")
  // 3. Perform interaction gestures (drag, scroll, key event) on the viewport
  // 4. Pump frame cycles to let animation/rebuild settle
  // 5. Assert that camera controller updates and HUD elements reflect changes
});
```

**Key difference:** Asserts on both the underlying camera controller state and the rendered HUD `Text` widgets (verifying that they do not reset or remain stale after interactions/parent widget rebuilds).

---

## Serial Execution Order

| Order | Issue | Test File | What It Tests | Depends On |
|-------|-------|-----------|---------------|------------|
| 1 | #50 | `test/cesium_3d/hud_update_test.dart` | Camera coordinates do not reset when parent widget notifies rebuilds | Nothing |
| 2 | #41 | `test/cesium_3d/camera_drag_test.dart` | Viewport drag gestures update camera coordinates | #50 |
| 3 | #44 | `test/cesium_3d/hud_update_test.dart` | HUD coordinate display updates and retains coordinates across parent rebuilds | #50 |
| 4 | #46 | `test/cesium_3d/shift_drag_test.dart` | Shift+drag modifies camera pitch and heading | #41 |
| 5 | #48 | `test/cesium_3d/ctrl_drag_test.dart` | Ctrl+drag modifies heading only | #41 |
| 6 | #47 | `test/cesium_3d/right_click_drag_test.dart` | Right-click drag modifies camera pitch and heading | #41 |
| 7 | #42 | `test/cesium_3d/scroll_zoom_test.dart` | Scroll signals change camera altitude | #41 |
| 8 | #43 | `test/cesium_3d/globe_focus_test.dart` | Arrow keys change camera state when viewport is focused | #50 |
| 9 | #49 | `test/cesium_3d/double_click_fly_test.dart` | Double-clicking viewport triggers camera fly-to animation | #41 |
| 10 | #51 | `test/cesium_3d/tile_imagery_repaint_test.dart` | Viewport repaints when asynchronous tile downloads complete | #41 |

---

## Test Specifications

### Test 1: #50 & #44 — Camera State and HUD Update across Parent Rebuilds

**File:** `app_flutter/test/cesium_3d/hud_update_test.dart`

**Assertion Flow:**
```
1. Render Scene3DViewport with a wrapping test widget that simulates parent rebuilds.
2. Verify initial coordinates on HUD containing "Latitude: 35.000000" and "Longitude: 135.000000".
3. Perform a pan action on the camera controller to update the camera position.
4. Verify that coordinates on the HUD update and do not match the old coordinates.
5. Trigger parent widget rebuild.
6. Verify that camera coordinates do not reset back to the initial stale values, and the HUD continues to display the correct updated coordinates.
```

---

### Test 2: #41 — Viewport Drag Changes Coordinates

**File:** `app_flutter/test/cesium_3d/camera_drag_test.dart`

**Assertion Flow:**
```
1. Render Scene3DViewport with defined initial coordinates.
2. Verify HUD coordinates match "Latitude: 35.000000" and "Longitude: 135.000000".
3. Drag left on the viewport (e.g., negative delta Offset(-100, 0)).
4. ASSERT: Dragging left increases the longitude.
5. Drag right on the viewport (e.g., positive delta Offset(100, 0)).
6. ASSERT: Dragging right decreases the longitude.
7. Verify that HUD coordinates are updated and the old values are no longer displayed.
```

---

### Test 3: #46, #48, #47 — Modifier Key Drag Interactions

**Files:**
- `app_flutter/test/cesium_3d/shift_drag_test.dart`
- `app_flutter/test/cesium_3d/ctrl_drag_test.dart`
- `app_flutter/test/cesium_3d/right_click_drag_test.dart`

**Assertion Flows:**

- **Shift+drag tilt (#46):**
  1. Render viewport and read initial camera pitch.
  2. Simulate Shift key down, drag vertically on the viewport, and raise Shift key.
  3. Verify that the camera pitch and heading have changed.

- **Ctrl+drag rotate heading (#48):**
  1. Render viewport and read initial camera heading.
  2. Simulate Control key down, drag horizontally on the viewport, and raise Control key.
  3. Verify that the camera heading has changed, while latitude, longitude, and pitch remain constant.

- **Right-click drag tilt (#47):**
  1. Render viewport and read initial camera pitch.
  2. Simulate right-click drag gesture (secondary mouse button drag).
  3. Verify that the camera pitch and heading have changed.

---

### Test 4: #42 — Scroll Zoom

**File:** `app_flutter/test/cesium_3d/scroll_zoom_test.dart`

**Assertion Flow:**
```
1. Render viewport and read initial camera altitude.
2. Dispatch pointer scroll signals (zoom gestures) on the viewport.
3. Verify that camera altitude changes in accordance with zoom sensitivity.
```

---

### Test 5: #43 — Viewport Focus and Keyboard Controls

**File:** `app_flutter/test/cesium_3d/globe_focus_test.dart`

**Assertion Flow:**
```
1. Render viewport and read initial camera heading/pitch.
2. Focus the viewport widget.
3. Send Arrow key events to rotate/tilt the view.
4. Verify that camera heading or pitch coordinates change.
```

---

### Test 6: #49 — Double-Click Fly-to Animation

**File:** `app_flutter/test/cesium_3d/double_click_fly_test.dart`

**Assertion Flow:**
```
1. Render viewport and read initial camera altitude.
2. Simulate a double-click gesture on the viewport.
3. Verify that the camera controller enters a flying state (`isFlying` is true).
4. Advance the frame time and verify that camera altitude decreases.
5. Wait for the animation to settle and verify that camera altitude is approximately halved.
```

---

### Test 7: #51 — Viewport Repaint on Asynchronous Tile Loads

**File:** `app_flutter/test/cesium_3d/tile_imagery_repaint_test.dart`

**Assertion Flow:**
```
1. Setup mock HTTP overrides to simulate tile imagery download.
2. Render viewport at high altitude to request low-zoom tiles.
3. Verify that viewport schedules repaints upon successful completion and decoding of asynchronous tile texture loads.
```

---

## Execution Protocol

### Command to run a single widget test:

```bash
flutter test test/cesium_3d/<test_file>.dart
```

### Command to run full suite:

```bash
flutter test test/cesium_3d/
```

---

## Guidelines

- Do NOT write a fix before a RED test confirms the bug behavior.
- Do NOT close an issue without raw GREEN test output.
- Assert on rendered HUD widget text strings (using search string finders "Latitude:" / "Longitude:") to verify client-facing correctness.
- Ensure that the workspace directory remains clean and all changes are pushed to remote trackers after passing local suites.
