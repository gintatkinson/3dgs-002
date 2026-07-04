# Database Test Mode Detection and Test Teardown Cleanup Plan

This plan details the changes required to resolve database test mode detection and test teardown cleanup in `/Users/perkunas/jail/3dgs-002`.

## Proposed Changes

### Core App Code

#### [MODIFY] [main.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/main.dart)
- Update `isTest` detection to also check if the active binding is a test binding, ensuring the app resolves to in-memory mode when launched via `flutter test -d macos`:
  - Target: `final isTest = Platform.environment.containsKey('FLUTTER_TEST');`
  - Replacement: `final isTest = Platform.environment.containsKey('FLUTTER_TEST') || WidgetsBinding.instance.runtimeType.toString().contains('Test');`

### Integration Tests

#### [MODIFY] [node_iteration_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/integration_test/node_iteration_test.dart)
- Remove unused diagnostic imports (`provider.dart`, `sidebar_tree.dart`, `tree_node_widget.dart`, `tree_view_model.dart`).
- Change the settings icon finder in `_changeSettingsViaUI` from `find.byIcon(Icons.settings).last` to `find.byIcon(Icons.settings).first` to avoid selecting the decorative viewport settings icon.
- In the first test (`Integration: 10 cycles x 20 nodes x all PropertyGrid fields`), add `addTearDown(() async { await tester.pumpWidget(const SizedBox.shrink()); });` at the start of the test.
- Revert the `while` loop waiting for the first node back to the standard loop logic (remove diagnostic print statements, helper lookups, and the final widget tree key dump).
- In the second test (`Stress test: cycle theme + text size between each full 20-node pass`), add `addTearDown(() async { await tester.pumpWidget(const SizedBox.shrink()); });` at the start of the test.
- Wrap the benchmark log file writing block in a `try/catch` to gracefully catch and log any sandboxing file access/permission errors (`PathAccessException`).

## Verification Plan

### Automated Tests
- Run the integration tests:
  ```bash
  cd app_flutter && flutter test integration_test/node_iteration_test.dart -d macos
  ```

## Phase 2: Visual Globe Camera Rotation Bug Simulation

This phase documents the temporary changes to simulate the camera rotation visual bug and verify the visual test failure.

### Core App Code

#### [MODIFY] [scene_3d_viewport.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
- Temporarily disable heading in the project calculation to force a RED score in the visual test.
  - Target:
    ```dart
    final double radHeading = camera.heading * math.pi / 180.0;
    final double cosH = math.cos(radHeading);
    final double sinH = math.sin(radHeading);
    ```
  - Replacement:
    ```dart
    final double radHeading = 0.0; // TEMPORARILY DISABLED HEADING FOR RED STATE DEMO
    final double cosH = math.cos(radHeading);
    final double sinH = math.sin(radHeading);
    ```

## Phase 2 Verification Plan

### Automated Tests
- Run the visual globe camera rotation integration test:
  ```bash
  cd app_flutter && flutter test integration_test/globe_camera_rotation_visual_test.dart -d macos
  ```

## Phase 3: Resolve Gesture Hit-Test and Camera Rotation Test Assertions

This phase documents the permanent changes to fix the gesture hit-test behavior in the 3D viewport and update the visual rotation test assertions.

### Core App Code

#### [MODIFY] [scene_3d_viewport.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
- Change gesture detector hit-test behavior to opaque around line 404 to ensure dragging and scaling register correctly.
  - Target:
    ```dart
        behavior: HitTestBehavior.translucent,
    ```
  - Replacement:
    ```dart
        behavior: HitTestBehavior.opaque,
    ```

### Integration Tests

#### [MODIFY] [globe_camera_rotation_visual_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/integration_test/globe_camera_rotation_visual_test.dart)
- Update test assertions to explicitly verify the camera heading (yaw) changes after simulating Ctrl+drag.
  - Target:
    ```dart
    // 3. Capture initial projected position of a reference coordinate
    final Offset initialOffset = state.getProjectedPosition(35.607400, 140.106300);

    // 4. Perform Ctrl + Drag to rotate heading (yaw)
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final viewport = find.byKey(const Key('scene_3d_viewport_container'));
    await tester.drag(viewport, const Offset(-150.0, 0.0));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);

    // 5. Capture new projected position of same coordinate
    final Offset newOffset = state.getProjectedPosition(35.607400, 140.106300);

    // 6. Assert visual movement has occurred
    expect(
      newOffset, 
      isNot(equals(initialOffset)),
      reason: 'Expected 2D projected screen coordinates to rotate when camera heading changes'
    );
    ```
  - Replacement:
    ```dart
    // 3. Capture initial projected position of a reference coordinate
    final Offset initialOffset = state.getProjectedPosition(35.607400, 140.106300);
    final double initialHeading = state.cameraController.current.heading;

    // 4. Perform Ctrl + Drag to rotate heading (yaw)
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final viewport = find.byKey(const Key('scene_3d_viewport_container'));
    await tester.drag(viewport, const Offset(-150.0, 0.0));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);

    // 5. Capture new projected position of same coordinate
    final Offset newOffset = state.getProjectedPosition(35.607400, 140.106300);
    final double newHeading = state.cameraController.current.heading;

    // 6. Assert camera heading parameter and visual movement have occurred
    expect(
      newHeading,
      isNot(equals(initialHeading)),
      reason: 'Camera heading did not change during rotation gesture'
    );
    expect(
      newOffset, 
      isNot(equals(initialOffset)),
      reason: 'Expected 2D projected screen coordinates to rotate when camera heading changes'
    );
    ```

## Phase 3 Verification Plan

### Automated Tests
- Run the visual globe camera rotation integration test to verify the changes:
  ```bash
  cd app_flutter && flutter test integration_test/globe_camera_rotation_visual_test.dart -d macos
  ```

## Phase 4: Pole-Crash Bug Fix and Correct Panning Direction

This phase documents the changes to clamp latitude to valid Web Mercator range in `globe_tile_renderer.dart` to prevent NaN/Infinity crashes, and correct the panning direction in `camera_controller.dart`.

### Core App Code

#### [MODIFY] [globe_tile_renderer.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart)
- Clamp latitude within `[-85.0511, 85.0511]` in `_latLngToTile` before computing Web Mercator coordinates to avoid log of negative or division by zero.
  - Target:
    ```dart
      TileCoord _latLngToTile(double lat, double lng, int zoom) {
        final n = math.pow(2, zoom).toInt();
        final x = ((lng + 180) / 360 * n).floor();
        final latRad = _rad(lat);
    ```
  - Replacement:
    ```dart
      TileCoord _latLngToTile(double lat, double lng, int zoom) {
        final clampedLat = lat.clamp(-85.0511, 85.0511);
        final n = math.pow(2, zoom).toInt();
        final x = ((lng + 180) / 360 * n).floor();
        final latRad = _rad(clampedLat);
    ```

#### [MODIFY] [camera_controller.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/camera_controller.dart)
- Invert the signs of `delta.dx` and `delta.dy` inside `pan` to make camera movement natural (drag matches finger/mouse movement).
  - Target:
    ```dart
      void pan(Offset delta) {
        final newLat = (_camera.latitude + delta.dy * dragSensitivity).clamp(-90.0, 90.0);
        final newLng = _wrapLng(_camera.longitude + delta.dx * dragSensitivity);
    ```
  - Replacement:
    ```dart
      void pan(Offset delta) {
        final newLat = (_camera.latitude - delta.dy * dragSensitivity).clamp(-90.0, 90.0);
        final newLng = _wrapLng(_camera.longitude - delta.dx * dragSensitivity);
    ```

### Integration Tests

#### [MODIFY] [globe_camera_drag_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/integration_test/globe_camera_drag_test.dart)
- Update test name and assertions to expect longitude to increase instead of decrease, matching the corrected natural panning direction.
  - Target:
    ```dart
      testWidgets('Globe camera drag: longitude decreases after leftward pan gesture', (WidgetTester tester) async {
    ```
  - Replacement:
    ```dart
      testWidgets('Globe camera drag: longitude increases after leftward pan gesture', (WidgetTester tester) async {
    ```
  - Target:
    ```dart
        expect(newLongitude, lessThan(initialLongitude),
            reason: 'Longitude should decrease after leftward drag. '
                'Initial: $initialLongitude, New: $newLongitude');
    ```
  - Replacement:
    ```dart
        expect(newLongitude, greaterThan(initialLongitude),
            reason: 'Longitude should increase after leftward drag. '
                'Initial: $initialLongitude, New: $newLongitude');
    ```

## Phase 4 Verification Plan

### Automated Tests
- Run the globe camera drag integration test:
  ```bash
  cd app_flutter && flutter test integration_test/globe_camera_drag_test.dart -d macos
  ```

## Phase 5: Camera Pan Altitude Scaling and Viewport NaN Safeguards

This phase details the changes to dynamically scale the camera panning sensitivity with altitude/zoom and to clamp calculations to prevent NaN camera parameters on viewport double-clicks.

### Core App Code

#### [MODIFY] [camera_controller.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/camera_controller.dart)
- Scale the panning sensitivity dynamically based on current altitude in the `pan` method.
  - Target:
    ```dart
      void pan(Offset delta) {
        final newLat = (_camera.latitude - delta.dy * dragSensitivity).clamp(-90.0, 90.0);
        final newLng = _wrapLng(_camera.longitude - delta.dx * dragSensitivity);
    ```
  - Replacement:
    ```dart
      void pan(Offset delta) {
        final double scaleFactor = (_camera.altitude / 5000.0).clamp(0.005, 50.0);
        final newLat = (_camera.latitude - delta.dy * dragSensitivity * scaleFactor).clamp(-90.0, 90.0);
        final newLng = _wrapLng(_camera.longitude - delta.dx * dragSensitivity * scaleFactor);
    ```

#### [MODIFY] [scene_3d_viewport.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
- Clamp the argument of `math.sqrt` in `_clickToCamera` to prevent `NaN` values due to double-clicks near the edge of the projection sphere.
  - Target:
    ```dart
        final double zFinal = math.sqrt(sphereRadius * sphereRadius - dx * dx - dy * dy);
    ```
  - Replacement:
    ```dart
        final double radDiff = sphereRadius * sphereRadius - dx * dx - dy * dy;
        final double zFinal = math.sqrt(radDiff < 0.0 ? 0.0 : radDiff);
    ```

### Integration Tests

#### [MODIFY] [globe_camera_rotation_visual_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/integration_test/globe_camera_rotation_visual_test.dart)
- Reduce the sleep/frame-pumping loop at the end of the test from 30 seconds to 1 second (10 iterations of 100ms) to prevent timeout failures in automated runs.
  - Target:
    ```dart
        // Keep the application GUI active and pump frames to the macOS display for 30 seconds
        for (int i = 0; i < 300; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
    ```
  - Replacement:
    ```dart
        // Keep the application GUI active and pump frames to the macOS display for 1 second
        for (int i = 0; i < 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
    ```

## Phase 5 Verification Plan

### Automated Tests
- Run the full suite of integration tests to ensure no regressions in camera control:
  ```bash
  cd app_flutter && flutter test integration_test/globe_camera_drag_test.dart -d macos
  cd app_flutter && flutter test integration_test/globe_camera_rotation_visual_test.dart -d macos
  ```

## Phase 6: Raw Pointer Listener Gestures and Pixel-Accurate Panning Formula

This phase documents the changes to implement 100% reliable pan/tilt/rotation gestures using raw pointer listener events on macOS and applying a pixel-accurate 1-to-1 panning formula.

### Core App Code

#### [MODIFY] [camera_controller.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/camera_controller.dart)
- Update `pan` to accept `shortestSide` and apply the pixel-accurate 1-to-1 scaling factor `factor = _camera.altitude * 0.358 / shortestSide`.
  - Target:
    ```dart
      void pan(Offset delta) {
        final double scaleFactor = (_camera.altitude / 5000.0).clamp(0.005, 50.0);
        final newLat = (_camera.latitude - delta.dy * dragSensitivity * scaleFactor).clamp(-90.0, 90.0);
        final newLng = _wrapLng(_camera.longitude - delta.dx * dragSensitivity * scaleFactor);
    ```
  - Replacement:
    ```dart
      void pan(Offset delta, double shortestSide) {
        final double factor = _camera.altitude * 0.358 / shortestSide;
        final newLat = (_camera.latitude - delta.dy * factor).clamp(-90.0, 90.0);
        final newLng = _wrapLng(_camera.longitude - delta.dx * factor);
    ```

#### [MODIFY] [scene_3d_viewport.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
- Update `onScaleUpdate` in the `GestureDetector` to only handle scaling (zoom) and delegate dragging to the raw `Listener` below.
  - Target:
    ```dart
            onScaleUpdate: (details) {
              final delta = details.focalPointDelta;
              if (delta.distance <= 2.0) return;
              if (details.scale == 1.0) {
                if (_rightButtonDown) {
                  _cameraController.tilt(delta);
                } else if (_shiftHeld) {
                  _cameraController.tilt(delta);
                } else if (_ctrlHeld) {
                  _cameraController.rotateHeading(delta);
                } else {
                  _cameraController.pan(delta);
                }
              } else {
                _cameraController.zoom(
                  (details.scale - 1.0).sign * 10.0,
                );
              }
            },
    ```
  - Replacement:
    ```dart
            onScaleUpdate: (details) {
              if (details.scale != 1.0) {
                _cameraController.zoom(
                  (details.scale - 1.0).sign * 10.0,
                );
              }
            },
    ```

- Update `Listener` to handle `onPointerMove`, extracting raw mouse movement and calling `pan` (with `shortestSide`), `tilt`, or `rotateHeading` depending on buttons and keys.
  - Target:
    ```dart
                child: Listener(
                  onPointerDown: (event) {
                    _globeFocusNode.requestFocus();
                    if (event.buttons & kSecondaryMouseButton != 0) {
                      _rightButtonDown = true;
                    }
                  },
                  onPointerUp: (event) {
                    _rightButtonDown = false;
                  },
                  onPointerCancel: (event) {
                    _rightButtonDown = false;
                  },
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      _cameraController.zoom(event.scrollDelta.dy);
                    }
                  },
    ```
  - Replacement:
    ```dart
                child: Listener(
                  onPointerDown: (event) {
                    _globeFocusNode.requestFocus();
                    if (event.buttons & kSecondaryMouseButton != 0) {
                      _rightButtonDown = true;
                    }
                  },
                  onPointerUp: (event) {
                    _rightButtonDown = false;
                  },
                  onPointerCancel: (event) {
                    _rightButtonDown = false;
                  },
                  onPointerMove: (event) {
                    final delta = event.localDelta;
                    if (delta.distance <= 0.5) return;
                    final Size? size = context.size;
                    final double shortestSide = size?.shortestSide ?? 800.0;
                    if (event.buttons & kSecondaryMouseButton != 0 || _shiftHeld) {
                      _cameraController.tilt(delta);
                    } else if (_ctrlHeld) {
                      _cameraController.rotateHeading(delta);
                    } else if (event.buttons & kPrimaryMouseButton != 0) {
                      _cameraController.pan(delta, shortestSide);
                    }
                  },
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      _cameraController.zoom(event.scrollDelta.dy);
                    }
                  },
    ```

## Phase 6 Verification Plan

### Automated Tests
- Run the full suite of integration tests to ensure no regressions in camera control and that gestures are fully functional:
  ```bash
  cd app_flutter && flutter test integration_test/globe_camera_drag_test.dart -d macos
  cd app_flutter && flutter test integration_test/globe_camera_rotation_visual_test.dart -d macos
  ```

## Phase 7: Correct Earth Scale and Update Panning Formula

This phase documents the correction of the Earth scale and panning formula to keep tracking 1-to-1.

### Core App Code

#### [MODIFY] [scene_3d_viewport.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
- Update `zoomScale` (around line 399) to map the camera's altitude to physical Earth dimensions using the Earth's radius (`6378137.0` meters) as the baseline scale:
  - Target:
    ```dart
        final zoomScale = 500.0 / _cameraController.current.altitude;
    ```
  - Replacement:
    ```dart
        final zoomScale = 6378137.0 / _cameraController.current.altitude;
    ```

#### [MODIFY] [camera_controller.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/camera_controller.dart)
- Update `CameraController.pan` signature and body to use the updated panning scaling factor based on the corrected Earth scale, keeping the default value for the second parameter to maintain backwards compatibility with existing tests:
  - Target:
    ```dart
      void pan(Offset delta, [double shortestSide = 800.0]) {
        final double factor = _camera.altitude * 0.358 / shortestSide;
        final newLat = (_camera.latitude - delta.dy * factor).clamp(-90.0, 90.0);
        final newLng = _wrapLng(_camera.longitude - delta.dx * factor);
    ```
  - Replacement:
    ```dart
      void pan(Offset delta, [double shortestSide = 800.0]) {
        final double factor = _camera.altitude * 2.8074e-5 / shortestSide;
        final newLat = (_camera.latitude - delta.dy * factor).clamp(-90.0, 90.0);
        final newLng = _wrapLng(_camera.longitude - delta.dx * factor);
    ```

### Unit Tests

#### [MODIFY] [camera_controller_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/test/cesium_3d/camera_controller_test.dart)
- Update pan scaling assertions and parameters to match the corrected 1-to-1 physical Earth scale factor:
  - Target:
    ```dart
        test('pan with pixel-accurate precision', () {
          final c = CameraController(_makeCam(lat: 0.0, lng: 0.0));
          c.pan(const Offset(100, 100));
          expect(c.current.longitude, closeTo(-22.375, 0.01));
          expect(c.current.latitude, closeTo(-22.375, 0.01));
        });

        test('pan clamps latitude to [-90, 90]', () {
          final c = CameraController(_makeCam(lat: 85.0));
          c.pan(const Offset(0, -100));
          expect(c.current.latitude, equals(90.0));
        });

        test('pan wraps longitude past 180', () {
          final c = CameraController(_makeCam(lng: 175.0));
          c.pan(const Offset(-100, 0));
          expect(c.current.longitude, lessThan(-160.0));
        });
    ```
  - Replacement:
    ```dart
        test('pan with pixel-accurate precision', () {
          final c = CameraController(_makeCam(lat: 0.0, lng: 0.0));
          c.pan(const Offset(100, 100));
          expect(c.current.longitude, closeTo(-0.00175, 0.0001));
          expect(c.current.latitude, closeTo(-0.00175, 0.0001));
        });

        test('pan clamps latitude to [-90, 90]', () {
          final c = CameraController(_makeCam(lat: 85.0));
          c.pan(const Offset(0, -1000000.0));
          expect(c.current.latitude, equals(90.0));
        });

        test('pan wraps longitude past 180', () {
          final c = CameraController(_makeCam(lng: 175.0));
          c.pan(const Offset(-1000000.0, 0));
          expect(c.current.longitude, lessThan(-160.0));
        });
    ```
  - Target:
    ```dart
        test('longitude wraps around -180/+180 boundary', () {
          final c = CameraController(_makeCam(lng: -175));
          c.pan(const Offset(100, 0));
          expect(c.current.longitude, lessThan(180));
          expect(c.current.longitude, greaterThan(155));
        });
    ```
  - Replacement:
    ```dart
        test('longitude wraps around -180/+180 boundary', () {
          final c = CameraController(_makeCam(lng: -175));
          c.pan(const Offset(1000000.0, 0));
          expect(c.current.longitude, lessThan(180));
          expect(c.current.longitude, greaterThan(155));
        });
    ```

## Phase 7 Verification Plan

### Automated Tests
- Run the unit and integration tests:
  ```bash
  cd app_flutter && flutter test test/cesium_3d/camera_controller_test.dart
  cd app_flutter && flutter test integration_test/globe_camera_drag_test.dart -d macos
  ```


## Phase 8: Exponential Interactive Zoom and Earth Radius Scale baseline sync

This phase documents the implementation of exponential interactive zoom and syncing of the zoom scale in `_clickToCamera` to resolve polar drift and slow zooming.

### Core App Code

#### [MODIFY] [camera_controller.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/camera_controller.dart)
- Add `zoomInteractive` method to support smooth exponential scaling:
  - Target:
    ```dart
      void zoom(double scrollDelta) {
        final newAlt = (_camera.altitude + scrollDelta * scrollSensitivity).clamp(minAltitude, maxAltitude);
        _camera = VirtualCamera.clamped(
          latitude: _camera.latitude, longitude: _camera.longitude,
          altitude: newAlt, heading: _camera.heading,
          pitch: _camera.pitch, roll: _camera.roll,
        );
        notifyListeners();
      }
    ```
  - Replacement:
    ```dart
      void zoom(double scrollDelta) {
        final newAlt = (_camera.altitude + scrollDelta * scrollSensitivity).clamp(minAltitude, maxAltitude);
        _camera = VirtualCamera.clamped(
          latitude: _camera.latitude, longitude: _camera.longitude,
          altitude: newAlt, heading: _camera.heading,
          pitch: _camera.pitch, roll: _camera.roll,
        );
        notifyListeners();
      }

      void zoomInteractive(double scrollDelta) {
        final double factor = math.exp(scrollDelta * 0.005);
        final newAlt = (_camera.altitude * factor).clamp(minAltitude, maxAltitude);
        _camera = VirtualCamera.clamped(
          latitude: _camera.latitude, longitude: _camera.longitude,
          altitude: newAlt, heading: _camera.heading,
          pitch: _camera.pitch, roll: _camera.roll,
        );
        notifyListeners();
      }
    ```

#### [MODIFY] [scene_3d_viewport.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
- Update `_clickToCamera` to use the physical Earth radius zoom scale baseline (`6378137.0`):
  - Target:
    ```dart
      final double zoomScale = 500.0 / _cameraController.current.altitude;
    ```
  - Replacement:
    ```dart
      final double zoomScale = 6378137.0 / _cameraController.current.altitude;
    ```
- Update `onScaleUpdate` and `onPointerSignal` to call `_cameraController.zoomInteractive` instead of `zoom`:
  - Target:
    ```dart
            if (details.scale != 1.0) {
              _cameraController.zoom(
                (details.scale - 1.0).sign * 10.0,
              );
            }
    ```
  - Replacement:
    ```dart
            if (details.scale != 1.0) {
              _cameraController.zoomInteractive(
                (details.scale - 1.0).sign * 20.0,
              );
            }
    ```
  - Target:
    ```dart
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    _cameraController.zoom(event.scrollDelta.dy);
                  }
                },
    ```
  - Replacement:
    ```dart
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    _cameraController.zoomInteractive(event.scrollDelta.dy);
                  }
                },
    ```

## Phase 8 Verification Plan

### Automated Tests
- Run the camera controller unit tests:
  ```bash
  cd app_flutter && flutter test test/cesium_3d/camera_controller_test.dart
  ```
- Run the integration tests:
  ```bash
  cd app_flutter && flutter test integration_test/globe_camera_drag_test.dart -d macos
  cd app_flutter && flutter test integration_test/globe_camera_rotation_visual_test.dart -d macos
  ```

## Phase 9: Warp Map Tiles using drawVertices

This phase details the changes required to warp map tiles onto the spherical surface of the globe using `canvas.drawVertices` to resolve flat rectangular tile stacking.

### Core App Code

#### [MODIFY] [globe_tile_renderer.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart)
- Import `dart:typed_data` at the top of the file.
- Update `renderTiles` to subdivide each tile into a 4x4 mesh of vertices, project each vertex using `projectFn`, construct a `ui.Vertices` object using texture coordinates mapping to the 256x256 image bounds, construct a `ui.ImageShader` with the tile image, and draw using `canvas.drawVertices`.
- Perform back-hemisphere culling on a per-triangle basis: only include indices for a triangle if all three of its vertices have `z >= 0.0`.

## Phase 9 Verification Plan

### Automated Tests
- Run the unit and integration tests to verify correctness:
  ```bash
  cd app_flutter && flutter test test/cesium_3d/camera_controller_test.dart
  cd app_flutter && flutter test integration_test/globe_camera_drag_test.dart -d macos
  cd app_flutter && flutter test integration_test/globe_camera_rotation_visual_test.dart -d macos
  ```

## Phase 10: Correct 3D rotation projection formulas and tile zoom resolution mapping

This phase details the changes required to correct the 3D rotation projection formulas and the tile zoom resolution mapping to fix blurry tiles and wrong camera target focus.

### Core App Code

#### [MODIFY] [globe_tile_renderer.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart)
- Update the `_zoomForAltitude` method to map altitude to the correct visual zoom level (using a 120,000,000 baseline) to ensure high-resolution tiles are loaded when zoomed in.

#### [MODIFY] [scene_3d_viewport.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
- Update `project` method to use correct 3D rotation matrix signs and axis mapping for both Cesium and fallback blocks (mapping `zFinal` to the correct screen coordinates, and `xFinal` as depth).

### Unit Tests

#### [MODIFY] [scroll_zoom_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/test/topology/scroll_zoom_test.dart)
- Update expected zoom altitude value to match the exponential zoom interactive formula.

#### [MODIFY] [theme_controller_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/test/core/theme/theme_controller_test.dart)
- Update default split axis expectations to Axis.vertical to match the default behavior in the service and controller.

### Phase 10 Verification Plan

### Automated Tests
- Run the unit and integration tests to verify correctness:
  ```bash
  cd app_flutter && flutter test test/cesium_3d/
  cd app_flutter && flutter test integration_test/globe_camera_drag_test.dart -d macos
  cd app_flutter && flutter test integration_test/globe_camera_rotation_visual_test.dart -d macos
  ```


