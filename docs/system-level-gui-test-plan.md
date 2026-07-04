# System-Level GUI Test Plan — 3D Geospatial Engine

**Date:** 2026-07-04
**Project:** 3dgs-002
**Status:** Draft — pending `PROCEED` for implementation

---

## Rules Compliance

| Rule | How enforced |
|------|-------------|
| `tdd-mandate.md` | Each bug: write failing integration test first (RED), confirm failure with raw output, then fix (GREEN), confirm pass with raw output |
| `serial-execution.md` | One bug at a time. Bug #50 first (root cause per handoff). No starting next until current verified, committed, closed |
| `verification-required.md` | Raw `flutter test` output pasted at every RED and GREEN step |
| `user-authorization-lock.md` | Each modifying action (write file, edit file, git commit, gh close) requires user `PROCEED` |
| `constitution-first.md` | No `.pipeline/constitution.md` exists in repo — N/A |
| `tracker-source-of-truth.md` | `gh issue view <N>` before working on any issue; `gh issue close` only after GREEN proof |
| `no-browser-automation.md` | All tests use `IntegrationTestWidgetsFlutterBinding` — no headless browser, no Playwright |
| `platform-independence.md` | N/A — integration tests are platform-specific by nature |

---

## Test Infrastructure

All tests use the existing E2E pattern from `integration_test/app_e2e_test.dart`:

```dart
IntegrationTestWidgetsFlutterBinding.ensureInitialized();

testWidgets('...', (WidgetTester tester) async {
  // 1. Set screen size (1280x800, pixelRatio 2.0)
  // 2. Load StringResources
  // 3. Create test SQLite DB (reuse createTestDatabase helper from app_e2e_test.dart)
  // 4. Create ThemeController + TextScalerController
  // 5. Boot MyApp() with Provider tree
  // 6. Settle (wait for spinners to clear, tree to load)
  // 7. Find "3D" toggle, tap if needed
  // 8. Interact
  // 9. Assert on rendered widget state (HUD Text, Finder results, not controller.current)
});
```

**Key difference from existing `globe_camera_drag_test.dart`:** asserts on **rendered output** (HUD `Text` widgets on screen) not in-memory `CameraController.current`. The old test passes because controller state mutates even when visual is frozen.

---

## Serial Execution Order

| Order | Issue | Test File | What It Tests | Depends On |
|-------|-------|-----------|---------------|------------|
| 1 | #50 | `integration_test/globe_camera_reset_test.dart` | Camera doesn't reset when tree notification fires | Nothing |
| 2 | #41 | `integration_test/globe_drag_test.dart` | Drag changes globe visual (HUD longitude changes) | #50 |
| 3 | #44 | (assertion in #50 test) | HUD doesn't show stale Master_1 values | #50 |
| 4 | #46 | `integration_test/globe_modifier_drag_test.dart` | Shift+drag triggers tilt (pitch changes) | #41 |
| 5 | #48 | (assertion in modifier test) | Ctrl/Cmd+drag triggers rotate (heading changes) | #41 |
| 6 | #47 | (assertion in modifier test) | Right-click drag triggers tilt | #41 |
| 7 | #42 | `integration_test/globe_scroll_zoom_test.dart` | Mouse wheel scroll changes altitude | #41 |
| 8 | #43 | `integration_test/globe_keyboard_test.dart` | Arrow keys rotate/tilt globe, not navigate tree | #50 |
| 9 | #49 | `integration_test/globe_double_tap_test.dart` | Double-click animates zoom-in (altitude halves) | #41 |

---

## Test Specifications

### Test 1: #50 — Camera Reset on Parent Rebuild

**File:** `app_flutter/integration_test/globe_camera_reset_test.dart`

**RED assertion:**
```
1. Boot MyApp() with test DB
2. Wait for sidebar tree to load (find.byKey('node_Master_1'))
3. Ensure 3D globe is active (find.byKey('toggle_3d'), tap if present)
4. Read Camera Stats HUD Text widgets (find text containing "Lat:", "Lng:", "Alt:")
5. Parse HUD lat/lng values from Text widget strings
6. Tap tree node Master_2 (find.byKey('node_Master_2'), tap)
7. Wait for rebuild (pump + settle)
8. Read HUD lat/lng again
9. ASSERT: HUD lat/lng are UNCHANGED from step 5
```

**Expected RED failure:** `_updateCurrentViewFromLayout` overwrites `_currentView` to `treeData.first.id` on every tree notification → HUD shows new view's coords → assertion fires.

**Why full app:** The bug trigger path is `Layout._onTreeViewModelChanged → _updateCurrentViewFromLayout → setState → TopographicalView.build → _resolveCamera → Scene3DViewport.didUpdateWidget`. Testing Scene3DViewport alone skips the first 3 steps.

---

### Test 2: #41 — Globe Drag Changes Visual

**File:** `app_flutter/integration_test/globe_drag_test.dart`

**RED assertion:**
```
1. Boot MyApp() with test DB
2. Switch to 3D globe
3. Wait for scene to settle
4. Read HUD longitude value from rendered Text
5. Drag CustomPaint left 200px (tester.drag(find.byType(CustomPaint).first, Offset(-200, 0)))
6. Pump + settle
7. Read HUD longitude again
8. ASSERT: longitude decreased (e.g., newLng < initialLng)
```

**Difference from existing test:** Asserts on rendered HUD Text, not `controller.current.longitude`. The existing test passes because the global pointer route mutates the controller but the visual is frozen.

---

### Test 3: #44 — HUD Stale Values

**Covered by Test 1 (#50).** Adds an extra assertion: after tree tap, HUD values match the last user-interaction values — not some default Master_1 coords. If #50 test passes, #44 is implicitly fixed.

---

### Test 4: #46, #48, #47 — Modifier Drags

**File:** `app_flutter/integration_test/globe_modifier_drag_test.dart`

**RED assertions (3 sub-tests):**

**4a. Shift+drag tilt (#46):**
```
1. Boot MyApp(), 3D globe active
2. Read HUD pitch value
3. Send ShiftLeft key down (tester.sendKeyDownEvent)
4. Drag globe vertically 100px
5. Send ShiftLeft key up
6. Read HUD pitch value
7. ASSERT: pitch changed from step 2
```

**4b. Ctrl/Cmd+drag rotate heading (#48):**
```
1. Read HUD heading value
2. Send ControlLeft key down
3. Drag globe horizontally 100px
4. Send ControlLeft key up
5. Read HUD heading value
6. ASSERT: heading changed from step 1
```

**4c. Right-click drag tilt (#47):**
```
1. Read HUD pitch value
2. Right-click drag on globe (tester.drag with secondary button via TestPointer)
3. Read HUD pitch value
4. ASSERT: pitch changed from step 1
```

---

### Test 5: #42 — Scroll Zoom

**File:** `app_flutter/integration_test/globe_scroll_zoom_test.dart`

**RED assertion:**
```
1. Boot MyApp(), 3D globe active
2. Read HUD altitude value from rendered Text
3. Dispatch PointerScrollEvent on globe (scroll down 10 notches)
4. Pump + settle
5. Read HUD altitude value
6. ASSERT: altitude changed (increased if scroll down = zoom out)
```

---

### Test 6: #43 — Arrow Keys

**File:** `app_flutter/integration_test/globe_keyboard_test.dart`

**RED assertion:**
```
1. Boot MyApp(), 3D globe active
2. Read HUD heading value
3. Tap globe to give it focus
4. Send ArrowRight key event
5. Read HUD heading value
6. ASSERT: heading changed (globe rotated)
7. OPTIONAL: assert tree selection did NOT change
```

---

### Test 7: #49 — Double-Click Fly-to

**File:** `app_flutter/integration_test/globe_double_tap_test.dart`

**RED assertion:**
```
1. Boot MyApp(), 3D globe active
2. Read HUD altitude value
3. Double-tap globe CustomPaint
4. Pump multiple frames to advance fly-to animation (tester.pump for 600ms)
5. Read HUD altitude value
6. ASSERT: altitude is approximately halved (within tolerance for animation in-progress)
```

---

## Execution Protocol

### For each bug:

```
[User PROCEED] → Write test file → [User PROCEED] →
Run test (RED) → paste raw output → Present fix plan →
[User PROCEED] → Apply fix → Run test (GREEN) → paste raw output →
Run flutter test (full suite) → paste raw output →
[User PROCEED] → git commit + push → gh issue close → move to next bug
```

### Command to run a single integration test:

```bash
cd app_flutter && flutter test -d macos integration_test/<test_file>.dart
```

### Command to run full suite:

```bash
cd app_flutter && flutter test
```

---

## What NOT to do

- Do NOT write a fix before the RED test confirms failure
- Do NOT close an issue without raw GREEN test output
- Do NOT start next bug while current bug's issue is still OPEN
- Do NOT use `controller.current` for assertions — assert on rendered widget state only
- Do NOT test Scene3DViewport in isolation — always boot `MyApp()` with full Layout tree
- Do NOT write isolated tests that pass but don't catch the real app bug
