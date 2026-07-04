# Camera Rotation Visual Alignment Plan

This plan details the changes required to resolve the camera rotation visual bug and verify the fix headfully on your screen.

## User Review Required

### Acceptance Criteria & Actions Matrix

| Acceptance Criteria | How We Achieve It |
|---|---|
| **1. Foreground App Window:** The application launches in a visible macOS desktop window (no frozen black screen). | Change the app identifier in [AppInfo.xcconfig](file:///Users/perkunas/jail/3dgs-002/app_flutter/macos/Runner/Configs/AppInfo.xcconfig) to a unique bundle ID to resolve macOS launch conflicts. |
| **2. Visual Globe Rotation:** The 3D globe, grid, and satellites rotate on screen when the rotation gesture is simulated. | Update the coordinate projection math inside [scene_3d_viewport.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart) to apply camera rotation to coordinates. |
| **3. Live Telemetry Updates:** The Yaw/Pitch stats panel updates on screen in real time during rotation. | Expose camera controller changes to trigger automatic custom painter redraws. |
| **4. Verification Window Duration:** The app window remains open and fully rendered for 30 seconds for verification. | Replace the sleep statement in [globe_camera_rotation_visual_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/integration_test/globe_camera_rotation_visual_test.dart) with a live frame-pumping loop (`tester.pump()`). |

## Open Questions

None.

## Proposed Changes

### App Configuration

#### [MODIFY] [AppInfo.xcconfig](file:///Users/perkunas/jail/3dgs-002/app_flutter/macos/Runner/Configs/AppInfo.xcconfig)
- Change `PRODUCT_BUNDLE_IDENTIFIER = com.example.appFlutter` to `com.example.appFlutter3dgs002`.

---

### Viewport and Gestures

#### [MODIFY] [scene_3d_viewport.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
- Expose `getProjectedPosition` and update the coordinate projection mathematics (`Scene3DViewportPainter.project`).

#### [MODIFY] [globe_camera_rotation_visual_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/integration_test/globe_camera_rotation_visual_test.dart)
- Replace static delay with a live `tester.pump()` loop.

---

### Hardcoded Path Cleanup

#### [MODIFY] [DebugProfile.entitlements](file:///Users/perkunas/jail/3dgs-002/app_flutter/macos/Runner/DebugProfile.entitlements)
- Replace `/jail/digital-pipeline-repo/` with `/jail/3dgs-002/` under `com.apple.security.temporary-exception.files.home-relative-path.read-write`.

#### [MODIFY] [node_iteration_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/integration_test/node_iteration_test.dart)
- Replace hardcoded benchmark results path with a environment variable or a relative fallback.

#### [MODIFY] [integration_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/test_driver/integration_test.dart)
- Replace hardcoded screenshot output directory with a environment variable.

#### [MODIFY] [run_profile_audit.py](file:///Users/perkunas/jail/3dgs-002/scripts/run_profile_audit.py)
- Replace hardcoded `repo_root` with a dynamically calculated directory based on the file location.

---

## Verification Plan

### Automated Tests
- Run the single visual integration test directly:
  ```bash
  flutter run integration_test/globe_camera_rotation_visual_test.dart -d macos
  ```

### Manual Verification
- Watch the macOS window open, display the active app GUI, and visually perform the camera rotation.
