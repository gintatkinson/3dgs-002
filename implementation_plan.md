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

## Phase 11: Implement 3D camera translation and rotation coordinates

This phase details the changes required to implement true 3D camera translation and rotation coordinates inside `Scene3DViewportPainter.project` to allow the focal center to move off the Earth's center.

### Core App Code

#### [MODIFY] [scene_3d_viewport.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
- Update `project` method to translate points relative to the camera's 3D position and then rotate by camera pitch and heading.

### Phase 11 Verification Plan

### Automated Tests
- Run the unit and integration tests to verify correctness:
  ```bash
  cd app_flutter && flutter test test/cesium_3d/
  cd app_flutter && flutter test integration_test/globe_camera_drag_test.dart -d macos
  cd app_flutter && flutter test integration_test/globe_camera_rotation_visual_test.dart -d macos
  ```


## Phase 12: Correct Globe Projection and Dynamic Sphere Alignment

This phase details the changes required to correct the camera pitch offset and project the background sphere and atmosphere glows dynamically, eliminating multiple globes and vertical oval distortion.

### Core App Code

#### [MODIFY] [scene_3d_viewport.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
- In `Scene3DViewportPainter.project`, change the pitch angle calculation to use the original `camera.pitch + 45.0` offset:
  - Target:
    ```dart
      final double P = camera.pitch * math.pi / 180.0;
    ```
  - Replacement:
    ```dart
      final double P = (camera.pitch + 45.0) * math.pi / 180.0;
    ```
- In `Scene3DViewportPainter.paint`, calculate the perspective-projected center and radius of the Earth sphere dynamically and replace references to the static `center` and `sphereRadius` for the starry corona, atmospheric glow, and planetary sphere.

### Phase 12 Verification Plan

### Automated Tests
- Run the unit and integration tests to verify correctness:
  ```bash
  cd app_flutter && flutter test test/cesium_3d/
  cd app_flutter && flutter test integration_test/globe_camera_drag_test.dart -d macos
  cd app_flutter && flutter test integration_test/globe_camera_rotation_visual_test.dart -d macos
  ```

## Phase 13: Horizon Culling

This phase documents the introduction of a 1-line horizon culling check to prevent back-hemisphere coordinates from rendering over the front hemisphere.

### Core App Code

#### [MODIFY] [scene_3d_viewport.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
- Insert a horizon culling check right after camera latitude rotation:
  - Target:
    ```dart
        // 2. Rotate around camera East axis by camera latitude
        final double cosX = math.cos(-radLat);
        final double sinX = math.sin(-radLat);
        final double xRot = x1 * cosX - y1 * sinX;
        final double yRot = x1 * sinX + y1 * cosX;
        final double zRot = z1;

        // 3. Translate along camera line of sight (camera is at distance D)
        final double distancePixels = sphereRadius * (1.0 + camera.altitude / 6378137.0);
        final double xCam = xRot - distancePixels;
    ```
  - Replacement:
    ```dart
        // 2. Rotate around camera East axis by camera latitude
        final double cosX = math.cos(-radLat);
        final double sinX = math.sin(-radLat);
        final double xRot = x1 * cosX - y1 * sinX;
        final double yRot = x1 * sinX + y1 * cosX;
        final double zRot = z1;

        // Horizon culling check: is the point blocked by the Earth's sphere?
        final double distancePixels = sphereRadius * (1.0 + camera.altitude / 6378137.0);
        final double horizonLimit = sphereRadius * (sphereRadius / distancePixels);
        if (xRot < horizonLimit) {
          return ProjectedPoint(Offset.zero, -1.0);
        }

        // 3. Translate along camera line of sight (camera is at distance D)
        final double xCam = xRot - distancePixels;
    ```

## Phase 13 Verification Plan

### Automated Tests
- Run all unit and integration tests to verify correctness and no regressions:
  ```bash
  cd app_flutter && flutter test test/cesium_3d/
  cd app_flutter && flutter test integration_test/globe_camera_drag_test.dart -d macos
  cd app_flutter && flutter test integration_test/globe_camera_rotation_visual_test.dart -d macos
  ```

## Phase 14: Coordinate Projection Cull Values and Lines Stretching Fix

This phase documents the changes required to fix coordinate projection culling values and update climate bands and orbit loops to resolve lines stretching to the top-left corner.

### Core App Code

#### [MODIFY] [scene_3d_viewport.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
- Calculate actual projected coordinates instead of returning `Offset.zero` when a point is behind the horizon, setting depth to `-1.0` if culled.
  - Target:
    ```dart
        // Horizon culling check: is the point blocked by the Earth's sphere?
        final double distancePixels = sphereRadius * (1.0 + camera.altitude / 6378137.0);
        final double horizonLimit = sphereRadius * (sphereRadius / distancePixels);
        if (xRot < horizonLimit) {
          return ProjectedPoint(Offset.zero, -1.0);
        }
    ```
  - Replacement:
    ```dart
        // Horizon culling check: is the point blocked by the Earth's sphere?
        final double distancePixels = sphereRadius * (1.0 + camera.altitude / 6378137.0);
        final double horizonLimit = sphereRadius * (sphereRadius / distancePixels);
        final double depthVal = xRot < horizonLimit ? -1.0 : depth;
    ```
- Update `paint` climate bands loop to only add vertices where `p.z >= 0.0`.
  - Target:
    ```dart
        final List<ProjectedPoint> pts = [];
        for (int s = 0; s <= steps; s++) {
          final double lng = s * (2 * math.pi / steps);
          pts.add(project(latMin, lng, sphereRadius * 1.002, center, rotationAngle, tilt));
        }
        for (int s = steps; s >= 0; s--) {
          final double lng = s * (2 * math.pi / steps);
          pts.add(project(latMax, lng, sphereRadius * 1.002, center, rotationAngle, tilt));
        }

        final double avgZ = pts.fold(0.0, (sum, p) => sum + p.z) / pts.length;
        if (avgZ >= -sphereRadius * 0.2) {
          final Path path = Path();
          path.moveTo(pts.first.offset.dx, pts.first.offset.dy);
          for (int i = 1; i < pts.length; i++) {
            path.lineTo(pts[i].offset.dx, pts[i].offset.dy);
          }
          path.close();
          canvas.drawPath(path, bandPaint);
          canvas.drawPath(path, bandBorder);
        }
    ```
  - Replacement:
    ```dart
        final List<ProjectedPoint> pts = [];
        for (int s = 0; s <= steps; s++) {
          final double lng = s * (2 * math.pi / steps);
          final p = project(latMin, lng, sphereRadius * 1.002, center, rotationAngle, tilt);
          if (p.z >= 0.0) pts.add(p);
        }
        for (int s = steps; s >= 0; s--) {
          final double lng = s * (2 * math.pi / steps);
          final p = project(latMax, lng, sphereRadius * 1.002, center, rotationAngle, tilt);
          if (p.z >= 0.0) pts.add(p);
        }

        if (pts.length >= 3) {
          final Path path = Path();
          path.moveTo(pts.first.offset.dx, pts.first.offset.dy);
          for (int i = 1; i < pts.length; i++) {
            path.lineTo(pts[i].offset.dx, pts[i].offset.dy);
          }
          path.close();
          canvas.drawPath(path, bandPaint);
          canvas.drawPath(path, bandBorder);
        }
    ```
- Update `paint` space trajectory loops to use `stepProj.z >= 0.0` instead of `stepProj.z >= -sphereRadius * 0.2`.
  - Target:
    ```dart
          if (stepProj.z >= -sphereRadius * 0.2) {
    ```
  - Replacement:
    ```dart
          if (stepProj.z >= 0.0) {
    ```

### Phase 14 Verification Plan

### Automated Tests
- Run all unit and integration tests to verify correctness:
  ```bash
  cd app_flutter && flutter test test/cesium_3d/
  cd app_flutter && flutter test integration_test/globe_camera_drag_test.dart -d macos
  cd app_flutter && flutter test integration_test/globe_camera_rotation_visual_test.dart -d macos
  ```


## Phase 15: Clean Orthographic Projection Reversion

This phase details the changes required to revert 3D projection formulas and background sphere rendering to use clean Orthographic (Parallel) Projection, resolving shape distortions and aligning the background sphere perfectly with the map tiles.

### Core App Code

#### [MODIFY] [scene_3d_viewport.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
- Update `Scene3DViewportPainter.project` to implement orthographic projection (no perspective division) and simple front-hemisphere culling.
- In `Scene3DViewportPainter.paint`, revert the background sphere, corona, atmosphere glows, and Proxima Centauri flares to use the static `center` and `sphereRadius` coordinates directly.
- Update `getProjectedPosition` to use the correct `6378137.0 / camera.altitude` zoomScale formula.

## Phase 15 Verification Plan

### Automated Tests
- Run the unit and integration tests to verify correctness:
  ```bash
  cd app_flutter && flutter test test/cesium_3d/
  cd app_flutter && flutter test integration_test/globe_camera_drag_test.dart -d macos
  cd app_flutter && flutter test integration_test/globe_camera_rotation_visual_test.dart -d macos
  ```

## Phase 16: True 3D Perspective Camera Model, Multi-resolution Base Tile Pyramid, and Double-click Gesture Sync

This phase documents the implementation of the true 3D perspective camera model, multi-resolution base tile pyramid, and updating the double-click gesture sync.

### Core App Code

#### [MODIFY] [globe_tile_renderer.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart)
- In `_visibleTiles`, always include the 16 base tiles of zoom level 2.
- In `renderTiles`, sort `_loadedImages` entries by zoom level before drawing so that lower-zoom base tiles are drawn first, and detailed tiles are drawn on top.

#### [MODIFY] [scene_3d_viewport.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
- Implement the true 3D camera model, ENU basis projection, and perspective projection in `Scene3DViewportPainter.project`.
- Update `Scene3DViewportPainter.paint` to pass `size` to all `project` calls and use physical height values (e.g. `6378137.0` for tiles/surface and `6378137.0 + alt` for nodes).
- Update the `_clickToCamera` logic to calculate `dx` and `dy` relative to `projectedCenter` instead of static `center`.

## Phase 16 Verification Plan

### Automated Tests
- Run the unit and integration tests to verify correctness:
  ```bash
  cd app_flutter && flutter test test/cesium_3d/
  cd app_flutter && flutter test integration_test/globe_camera_drag_test.dart -d macos
  cd app_flutter && flutter test integration_test/globe_camera_rotation_visual_test.dart -d macos
  ```

## Phase 17: Heading-Aligned Panning

This phase details the changes required to rotate the drag delta by the camera's heading so that panning aligns with screen axes.

### Core App Code

#### [MODIFY] [camera_controller.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/camera_controller.dart)
- Modify the `pan` method to rotate the drag delta by the camera's heading:
  - Target:
    ```dart
      void pan(Offset delta, [double shortestSide = 800.0]) {
        final double factor = _camera.altitude * 2.8074e-5 / shortestSide;
        final newLat = (_camera.latitude - delta.dy * factor).clamp(-90.0, 90.0);
        final newLng = _wrapLng(_camera.longitude - delta.dx * factor);
        _camera = VirtualCamera.clamped(
          latitude: newLat, longitude: newLng,
          altitude: _camera.altitude, heading: _camera.heading,
          pitch: _camera.pitch, roll: _camera.roll,
        );
        notifyListeners();
      }
    ```
  - Replacement:
    ```dart
      void pan(Offset delta, [double shortestSide = 800.0]) {
        final double factor = _camera.altitude * 2.8074e-5 / shortestSide;
        
        // Rotate the drag delta by the camera heading to align panning with the screen axes
        final double radH = _camera.heading * math.pi / 180.0;
        final double cosH = math.cos(radH);
        final double sinH = math.sin(radH);
        
        final double dxAligned = delta.dx * cosH + delta.dy * sinH;
        final double dyAligned = -delta.dx * sinH + delta.dy * cosH;
        
        final newLat = (_camera.latitude - dyAligned * factor).clamp(-90.0, 90.0);
        final newLng = _wrapLng(_camera.longitude - dxAligned * factor);
        _camera = VirtualCamera.clamped(
          latitude: newLat, longitude: newLng,
          altitude: _camera.altitude, heading: _camera.heading,
          pitch: _camera.pitch, roll: _camera.roll,
        );
        notifyListeners();
      }
    ```

### Phase 17 Verification Plan

### Automated Tests
- Run all unit and integration tests to verify correctness:
  ```bash
  cd app_flutter && flutter test test/cesium_3d/
  cd app_flutter && flutter test integration_test/globe_camera_drag_test.dart -d macos
  cd app_flutter && flutter test integration_test/globe_camera_rotation_visual_test.dart -d macos
  ```

## Phase 18: Expand Camera Pitch Limits with Wrapping

This phase details the changes required to expand the camera pitch limits to the full 360-degree range in the CameraController by wrapping the pitch parameter between [-180.0, 180.0].

### Core App Code

#### [MODIFY] [camera_controller.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/camera_controller.dart)
- Remove `minPitch` and `maxPitch` constants.
- Implement the `_wrapPitch` helper function to wrap values to the `[-180.0, 180.0]` range.
- Replace pitch clamping with `_wrapPitch` wherever pitch is updated.

### Phase 18 Verification Plan

### Automated Tests
- Run the unit and integration tests to verify correctness:
  ```bash
  cd app_flutter && flutter test test/cesium_3d/
  cd app_flutter && flutter test integration_test/globe_camera_drag_test.dart -d macos
  cd app_flutter && flutter test integration_test/globe_camera_rotation_visual_test.dart -d macos
  ```

## Phase 19: Panning Sensitivity Baseline and Drag Jitter Filter Threshold Update

This phase details the changes required to update the panning sensitivity baseline offset to resolve the left/right panning lock and reduce the drag distance discard threshold to improve low-altitude flight responsiveness.

### Core App Code

#### [MODIFY] [camera_controller.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/camera_controller.dart)
- In `pan`, add a `500,000.0` meters baseline offset to the altitude in the panning sensitivity factor calculation.
  - Target:
    ```dart
      void pan(Offset delta, [double shortestSide = 800.0]) {
        final double factor = _camera.altitude * 2.8074e-5 / shortestSide;
    ```
  - Replacement:
    ```dart
      void pan(Offset delta, [double shortestSide = 800.0]) {
        final double factor = (_camera.altitude + 500000.0) * 2.8074e-5 / shortestSide;
    ```

#### [MODIFY] [scene_3d_viewport.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
- In `onPointerMove`, reduce the drag distance discard threshold from `0.5` to `0.01` to prevent trackpad sub-pixel micro-drags from being ignored.
  - Target:
    ```dart
                    final delta = event.localDelta;
                    if (delta.distance <= 0.5) return;
    ```
  - Replacement:
    ```dart
                    final delta = event.localDelta;
                    if (delta.distance <= 0.01) return;
    ```

### Unit Tests

#### [MODIFY] [camera_controller_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/test/cesium_3d/camera_controller_test.dart)
- Update expected longitude and latitude change to reflect the added 500,000 meters altitude offset in panning sensitivity calculations.
- Update large wrap-testing input offsets from `1,000,000.0` to `1,000.0` so that they wrap appropriately under the new panning sensitivity scaling factor.
  - Target:
    ```dart
        test('pan with pixel-accurate precision', () {
          final c = CameraController(_makeCam(lat: 0.0, lng: 0.0));
          c.pan(const Offset(100, 100));
          expect(c.current.longitude, closeTo(-0.00175, 0.0001));
          expect(c.current.latitude, closeTo(-0.00175, 0.0001));
        });
    ```
  - Replacement:
    ```dart
        test('pan with pixel-accurate precision', () {
          final c = CameraController(_makeCam(lat: 0.0, lng: 0.0));
          c.pan(const Offset(100, 100));
          expect(c.current.longitude, closeTo(-1.75638, 0.0001));
          expect(c.current.latitude, closeTo(-1.75638, 0.0001));
        });
    ```
  - Target:
    ```dart
        test('pan wraps longitude past 180', () {
          final c = CameraController(_makeCam(lng: 175.0));
          c.pan(const Offset(-1000000.0, 0));
          expect(c.current.longitude, lessThan(-160.0));
        });
    ```
  - Replacement:
    ```dart
        test('pan wraps longitude past 180', () {
          final c = CameraController(_makeCam(lng: 175.0));
          c.pan(const Offset(-1000.0, 0));
          expect(c.current.longitude, lessThan(-160.0));
        });
    ```
  - Target:
    ```dart
        test('longitude wraps around -180/+180 boundary', () {
          final c = CameraController(_makeCam(lng: -175));
          c.pan(const Offset(1000000.0, 0));
          expect(c.current.longitude, lessThan(180));
          expect(c.current.longitude, greaterThan(155));
        });
    ```
  - Replacement:
    ```dart
        test('longitude wraps around -180/+180 boundary', () {
          final c = CameraController(_makeCam(lng: -175));
          c.pan(const Offset(1000.0, 0));
          expect(c.current.longitude, lessThan(180));
          expect(c.current.longitude, greaterThan(155));
        });
    ```

### Phase 19 Verification Plan

### Automated Tests
- Run all unit and integration tests to verify correctness:
  ```bash
  cd app_flutter && flutter test test/cesium_3d/
  cd app_flutter && flutter test integration_test/globe_camera_drag_test.dart -d macos
  cd app_flutter && flutter test integration_test/globe_camera_rotation_visual_test.dart -d macos
  ```

## Phase 20: Keyboard Rotate Heading (Yaw) with Shift + Arrow Keys

This phase implements camera heading (yaw) rotation on Shift + Left/Right arrow keys instead of globe longitude rotation.

### Core App Code

#### [MODIFY] [camera_controller.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/camera_controller.dart)
- Implement `keyboardRotateHeading` which wraps and updates the heading (yaw) parameter.
- Update `_wrapHeadingStatic` to use `heading >= 360` so that 360-degree boundary wraps correctly to 0.

#### [MODIFY] [scene_3d_viewport.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
- In `_handleKeyEvent`, check if `_shiftHeld` is true when Left/Right arrows are pressed and delegate to `keyboardRotateHeading`.

### Unit and Integration Tests

#### [MODIFY] [camera_controller_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/test/cesium_3d/camera_controller_test.dart)
- Add unit test for `keyboardRotateHeading`.

#### [MODIFY] [globe_focus_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/test/cesium_3d/globe_focus_test.dart)
- Add test case verifying that pressing Shift + Left/Right arrow keys rotates camera heading instead of longitude.

### Phase 20 Verification Plan

### Automated Tests
- Run unit and widget tests:
  ```bash
  cd app_flutter && flutter test test/cesium_3d/
  ```


## Phase 21: Dynamic Table Row Heights and Controllable Panel Opacity Setting

This phase implements dynamic table row heights and adds a controllable panel opacity slider to the settings panel, applied to the sidebar, tabbed container, and properties panel.

### Core App Code

#### [MODIFY] [theme_service.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/core/theme/theme_service.dart)
- Add abstract methods to `ThemeService`:
  - Target:
    ```dart
      /// Persists [axis] so it survives app restarts.
      Future<void> saveLayoutSplitAxis(Axis axis);
    }
    ```
  - Replacement:
    ```dart
      /// Persists [axis] so it survives app restarts.
      Future<void> saveLayoutSplitAxis(Axis axis);

      /// Loads the persisted panel opacity; defaults to `0.85`.
      Future<double> loadPanelOpacity();

      /// Persists the panel [opacity] so it survives app restarts.
      Future<void> savePanelOpacity(double opacity);
    }
    ```
- Implement methods in `SharedPreferencesThemeService`:
  - Target:
    ```dart
      static const _layoutSplitAxisKey = 'layout_split_axis';
    ```
  - Replacement:
    ```dart
      static const _layoutSplitAxisKey = 'layout_split_axis';
      static const _panelOpacityKey = 'panel_opacity';
    ```
  - Target:
    ```dart
      /// Writes a "horizontal" or "vertical" string.
      @override
      Future<void> saveLayoutSplitAxis(Axis axis) async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final value = axis == Axis.vertical ? 'vertical' : 'horizontal';
          await prefs.setString(_layoutSplitAxisKey, value);
        } catch (e, stackTrace) {
          debugPrint('Error in saveLayoutSplitAxis: $e\n$stackTrace');
        }
      }
    }
    ```
  - Replacement:
    ```dart
      /// Writes a "horizontal" or "vertical" string.
      @override
      Future<void> saveLayoutSplitAxis(Axis axis) async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final value = axis == Axis.vertical ? 'vertical' : 'horizontal';
          await prefs.setString(_layoutSplitAxisKey, value);
        } catch (e, stackTrace) {
          debugPrint('Error in saveLayoutSplitAxis: $e\n$stackTrace');
        }
      }

      @override
      Future<double> loadPanelOpacity() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          return prefs.getDouble(_panelOpacityKey) ?? 0.85;
        } catch (e, stackTrace) {
          debugPrint('Error in loadPanelOpacity: $e\n$stackTrace');
          return 0.85;
        }
      }

      @override
      Future<void> savePanelOpacity(double opacity) async {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble(_panelOpacityKey, opacity);
        } catch (e, stackTrace) {
          debugPrint('Error in savePanelOpacity: $e\n$stackTrace');
        }
      }
    }
    ```

#### [MODIFY] [theme_controller.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/core/theme/theme_controller.dart)
- Add a private field `_panelOpacity`, its getter, load logic in `loadSettings()`, and a mutation method `updatePanelOpacity`:
  - Target:
    ```dart
      ThemeController(this._themeService);
      final ThemeService _themeService;
      ThemeMode _themeMode = ThemeMode.system;
      int _currentThemeIndex = 0;
      Axis _layoutSplitAxis = Axis.vertical;

      /// Current [ThemeMode] (light / dark / system).
    ```
  - Replacement:
    ```dart
      ThemeController(this._themeService);
      final ThemeService _themeService;
      ThemeMode _themeMode = ThemeMode.system;
      int _currentThemeIndex = 0;
      Axis _layoutSplitAxis = Axis.vertical;
      double _panelOpacity = 0.85;

      /// Current [ThemeMode] (light / dark / system).
    ```
  - Target:
    ```dart
      /// Current layout split axis orientation.
      Axis get layoutSplitAxis => _layoutSplitAxis;
    ```
  - Replacement:
    ```dart
      /// Current layout split axis orientation.
      Axis get layoutSplitAxis => _layoutSplitAxis;

      /// Panel/overlay opacity between 0.0 and 1.0.
      double get panelOpacity => _panelOpacity;
    ```
  - Target:
    ```dart
      Future<void> loadSettings() async {
        _themeMode = await _themeService.loadThemeMode();
        _currentThemeIndex = await _themeService.loadThemeScheme();
        if (_currentThemeIndex < 0 || _currentThemeIndex >= AppThemes.customSchemes.length) {
          _currentThemeIndex = 0;
        }
        _layoutSplitAxis = await _themeService.loadLayoutSplitAxis();
        notifyListeners();
      }
    ```
  - Replacement:
    ```dart
      Future<void> loadSettings() async {
        _themeMode = await _themeService.loadThemeMode();
        _currentThemeIndex = await _themeService.loadThemeScheme();
        if (_currentThemeIndex < 0 || _currentThemeIndex >= AppThemes.customSchemes.length) {
          _currentThemeIndex = 0;
        }
        _layoutSplitAxis = await _themeService.loadLayoutSplitAxis();
        _panelOpacity = await _themeService.loadPanelOpacity();
        notifyListeners();
      }
    ```
  - Target:
    ```dart
      /// Updates the layout split axis orientation and persists it via [ThemeService].
      ///
      /// No-op when [newAxis] is null or matches the current value.
      /// Fires `notifyListeners()` before persisting.
      /// Persistence failure is silently swallowed.
      Future<void> updateLayoutSplitAxis(Axis? newAxis) async {
        if (newAxis == null || newAxis == _layoutSplitAxis) return;
        _layoutSplitAxis = newAxis;
        notifyListeners();
        await _themeService.saveLayoutSplitAxis(newAxis);
      }
    }
    ```
  - Replacement:
    ```dart
      /// Updates the layout split axis orientation and persists it via [ThemeService].
      ///
      /// No-op when [newAxis] is null or matches the current value.
      /// Fires `notifyListeners()` before persisting.
      /// Persistence failure is silently swallowed.
      Future<void> updateLayoutSplitAxis(Axis? newAxis) async {
        if (newAxis == null || newAxis == _layoutSplitAxis) return;
        _layoutSplitAxis = newAxis;
        notifyListeners();
        await _themeService.saveLayoutSplitAxis(newAxis);
      }

      /// Updates the panel opacity value and persists it via [ThemeService].
      ///
      /// No-op when [newOpacity] is null or matches the current value.
      /// Fires `notifyListeners()` before persisting.
      /// Persistence failure is silently swallowed.
      Future<void> updatePanelOpacity(double? newOpacity) async {
        if (newOpacity == null || newOpacity == _panelOpacity) return;
        _panelOpacity = newOpacity;
        notifyListeners();
        await _themeService.savePanelOpacity(newOpacity);
      }
    }
    ```

#### [MODIFY] [settings_panel.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/core/theme/widgets/settings_panel.dart)
- Add the "Overlay Opacity" slider underneath "Workspace Split":
  - Target:
    ```dart
              SegmentedButton<Axis>(
                segments: const [
                  ButtonSegment(
                    value: Axis.horizontal,
                    icon: Icon(Icons.splitscreen_outlined, size: 18),
                    label: Text('Horizontal'),
                  ),
                  ButtonSegment(
                    value: Axis.vertical,
                    icon: RotatedBox(
                      quarterTurns: 1,
                      child: Icon(Icons.splitscreen_outlined, size: 18),
                    ),
                    label: Text('Vertical'),
                  ),
                ],
                selected: {themeController.layoutSplitAxis},
                onSelectionChanged: (Set<Axis> newSelection) {
                  themeController.updateLayoutSplitAxis(newSelection.first);
                },
              ),
              const SizedBox(height: 16),

              Text('Color', style: Theme.of(context).textTheme.titleSmall),
    ```
  - Replacement:
    ```dart
              SegmentedButton<Axis>(
                segments: const [
                  ButtonSegment(
                    value: Axis.horizontal,
                    icon: Icon(Icons.splitscreen_outlined, size: 18),
                    label: Text('Horizontal'),
                  ),
                  ButtonSegment(
                    value: Axis.vertical,
                    icon: RotatedBox(
                      quarterTurns: 1,
                      child: Icon(Icons.splitscreen_outlined, size: 18),
                    ),
                    label: Text('Vertical'),
                  ),
                ],
                selected: {themeController.layoutSplitAxis},
                onSelectionChanged: (Set<Axis> newSelection) {
                  themeController.updateLayoutSplitAxis(newSelection.first);
                },
              ),
              const SizedBox(height: 16),
              Text('Overlay Opacity', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.opacity, size: 16, color: cs.onSurface.withValues(alpha: 0.5)),
                  Expanded(
                    child: Slider(
                      value: themeController.panelOpacity,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      label: '${(themeController.panelOpacity * 100).round()}%',
                      onChanged: (value) => themeController.updatePanelOpacity(value),
                    ),
                  ),
                  Icon(Icons.opacity, size: 22, color: cs.onSurface),
                ],
              ),
              const SizedBox(height: 16),

              Text('Color', style: Theme.of(context).textTheme.titleSmall),
    ```

#### [MODIFY] [sidebar_tree.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/tree/sidebar_tree.dart)
- Import `theme_controller.dart`, watch `ThemeController`, and apply opacity to `cardColor`:
  - Target:
    ```dart
    import 'package:flutter/services.dart';
    import 'package:provider/provider.dart';
    import 'package:app_flutter/core/theme/widgets/settings_panel.dart';
    ```
  - Replacement:
    ```dart
    import 'package:flutter/services.dart';
    import 'package:provider/provider.dart';
    import 'package:app_flutter/core/theme/theme_controller.dart';
    import 'package:app_flutter/core/theme/widgets/settings_panel.dart';
    ```
  - Target:
    ```dart
      @override
      Widget build(BuildContext context) {
        final viewModel = context.watch<TreeViewModel>();
        final treeData = viewModel.treeData;
        final brandPrimary = Theme.of(context).colorScheme.primary;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              right: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
    ```
  - Replacement:
    ```dart
      @override
      Widget build(BuildContext context) {
        final viewModel = context.watch<TreeViewModel>();
        final treeData = viewModel.treeData;
        final brandPrimary = Theme.of(context).colorScheme.primary;
        final panelOpacity = context.watch<ThemeController>().panelOpacity;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(panelOpacity),
            border: Border(
              right: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
    ```

#### [MODIFY] [tabbed_container.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/tables/tabbed_container.dart)
- Import `theme_controller.dart`, watch `ThemeController`, apply opacity to `cardColor` wrapping the entire `Column`, and set nested `Material`'s color to `Colors.transparent`:
  - Target:
    ```dart
    import 'package:flutter/material.dart';
    import 'package:provider/provider.dart';
    import 'package:app_flutter/features/tables/view_models/tables_view_model.dart';
    ```
  - Replacement:
    ```dart
    import 'package:flutter/material.dart';
    import 'package:provider/provider.dart';
    import 'package:app_flutter/core/theme/theme_controller.dart';
    import 'package:app_flutter/features/tables/view_models/tables_view_model.dart';
    ```
  - Target:
    ```dart
        if (_tabController == null) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            Material(
              color: Theme.of(context).cardColor,
              child: TabBar(
                controller: _tabController!,
                tabs: tabs.map((t) => Tab(text: t.label)).toList(),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController!,
                children: List.generate(tabs.length, (idx) {
                  return LazyTab(
                    isSelected: _tabController!.index == idx,
                    child: const TableViewWidget(),
                  );
                }),
              ),
            ),
          ],
        );
    ```
  - Replacement:
    ```dart
        if (_tabController == null) {
          return const SizedBox.shrink();
        }

        final panelOpacity = context.watch<ThemeController>().panelOpacity;
        return Container(
          color: Theme.of(context).cardColor.withOpacity(panelOpacity),
          child: Column(
            children: [
              Material(
                color: Colors.transparent,
                child: TabBar(
                  controller: _tabController!,
                  tabs: tabs.map((t) => Tab(text: t.label)).toList(),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController!,
                  children: List.generate(tabs.length, (idx) {
                    return LazyTab(
                      isSelected: _tabController!.index == idx,
                      child: const TableViewWidget(),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
    ```

#### [MODIFY] [component_factory.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/layout/component_factory.dart)
- Import `theme_controller.dart` and wrap `PropertiesPanel` case:
  - Target:
    ```dart
    import 'package:flutter/material.dart';
    import 'package:provider/provider.dart';
    import 'package:app_flutter/domain/data_source.dart';
    ```
  - Replacement:
    ```dart
    import 'package:flutter/material.dart';
    import 'package:provider/provider.dart';
    import 'package:app_flutter/core/theme/theme_controller.dart';
    import 'package:app_flutter/domain/data_source.dart';
    ```
  - Target:
    ```dart
          case 'TabbedContainer':
            return _TabbedContainerHost(currentView: currentView);
          case 'TableView':
            final id = node['id'] as String? ?? '';
            return _TableViewContainer(
              tabId: id,
              currentView: currentView,
            );
          default:
            return const SizedBox.shrink();
    ```
  - Replacement:
    ```dart
          case 'TabbedContainer':
            return _TabbedContainerHost(currentView: currentView);
          case 'TableView':
            final id = node['id'] as String? ?? '';
            return _TableViewContainer(
              tabId: id,
              currentView: currentView,
            );
          case 'PropertiesPanel':
            final panelOpacity = context.watch<ThemeController>().panelOpacity;
            return Container(
              color: Theme.of(context).cardColor.withOpacity(panelOpacity),
              child: buildChildWidget(context),
            );
          default:
            return const SizedBox.shrink();
    ```

#### [MODIFY] [table_view_widget.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/tables/table_view_widget.dart)
- Set `dataRowMaxHeight` default to `double.infinity` and remove the `maxHeight` constraint in `_DataRow.build`:
  - Target:
    ```dart
      const TableViewWidget({
        super.key,
        this.headingRowHeight = 32.0,
        this.dataRowMinHeight = 28.0,
        this.dataRowMaxHeight = 28.0,
        this.horizontalMargin = 12.0,
        this.columnSpacing = 24.0,
      });
    ```
  - Replacement:
    ```dart
      const TableViewWidget({
        super.key,
        this.headingRowHeight = 32.0,
        this.dataRowMinHeight = 28.0,
        this.dataRowMaxHeight = double.infinity,
        this.horizontalMargin = 12.0,
        this.columnSpacing = 24.0,
      });
    ```
  - Target:
    ```dart
      @override
      Widget build(BuildContext context) {
        return RepaintBoundary(
          child: Container(
            constraints: BoxConstraints(
              minHeight: dataRowMinHeight,
              maxHeight: dataRowMaxHeight,
            ),
            color: index.isEven ? null : Colors.black.withOpacity(0.03),
    ```
  - Replacement:
    ```dart
      @override
      Widget build(BuildContext context) {
        return RepaintBoundary(
          child: Container(
            constraints: BoxConstraints(
              minHeight: dataRowMinHeight,
            ),
            color: index.isEven ? null : Colors.black.withOpacity(0.03),
    ```

### Unit Tests

#### [MODIFY] [theme_controller_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/test/core/theme/theme_controller_test.dart)
- Update `FakeThemeService` to implement `loadPanelOpacity` and `savePanelOpacity`.
- Add test cases for `panelOpacity` initial value, loadSettings, and updatePanelOpacity.
- Add test cases for `SharedPreferencesThemeService` loading and saving panel opacity.

### Phase 21 Verification Plan

#### Automated Tests
- Run all project unit and widget tests:
  ```bash
  cd app_flutter && flutter test
  ```


## Phase 22: Stack-Based Foreground Positioning and PropertyGrid Opacity

This phase implements stack-based foreground positioning in SplitWorkspace, enables paintLeadingOnTop: true for the SidebarLayout, and sets opacity on the PropertyGrid input fields and cards.

### Core App Code

#### [MODIFY] [split_workspace.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/layout/split_workspace.dart)
- Add `paintLeadingOnTop` parameter to the constructor (defaulting to `false`).
- Rewrite `SplitWorkspaceState.build` to lay out the panes using a `Stack` of `Positioned` widgets instead of a `Row` or `Column`, ordering the children list dynamically based on `paintLeadingOnTop`.

#### [MODIFY] [component_factory.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/layout/component_factory.dart)
- In the `case 'SidebarLayout'` branch of `ComponentFactory.build`, pass `paintLeadingOnTop: true` to the `SplitWorkspace` constructor.

#### [MODIFY] [property_grid.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/properties/property_grid.dart)
- Watch `ThemeController` in `PropertyGrid.build` to retrieve `panelOpacity`.
- In `_buildSystemSection`, apply `panelOpacity` to the card background color `surfaceFill`.
- Pass `panelOpacity` to `_buildTextField`, `_buildDropdownField`, and `_buildCommittedStatePanel` and apply it to their respective `fillColor`, `dropdownColor`, and background/decorations colors.

### Phase 22 Verification Plan

#### Automated Tests
- Run all project unit and widget tests:
  ```bash
  cd app_flutter && flutter test
  ```
