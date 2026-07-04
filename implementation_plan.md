# Layout Split Axis Defaults and Integration Test physicalSize Overrides Plan

This plan details the changes required to update the default layout split axis to vertical and resolve integration test physicalSize overrides.

## Proposed Changes

### Theme Settings

#### [MODIFY] [theme_controller.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/core/theme/theme_controller.dart)
- Change default value of `_layoutSplitAxis` (around line 24) to `Axis.vertical`.

#### [MODIFY] [theme_service.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/core/theme/theme_service.dart)
- Change default case (around line 139) and exception catch fallback (around line 143) in `loadLayoutSplitAxis` to return `Axis.vertical`.

### Integration Tests

#### [MODIFY] [globe_camera_drag_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/integration_test/globe_camera_drag_test.dart)
- Replace physicalSize and devicePixelRatio overrides (lines 24-32) with binding-based surface size.

#### [MODIFY] [globe_camera_reset_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/integration_test/globe_camera_reset_test.dart)
- Replace physicalSize and devicePixelRatio overrides (lines 39-47) with binding-based surface size.

#### [MODIFY] [globe_camera_rotation_visual_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/integration_test/globe_camera_rotation_visual_test.dart)
- Replace physicalSize and devicePixelRatio overrides (lines 24-32) with binding-based surface size.

## Verification Plan

### Automated Tests
- Run the integration tests locally to verify success:
  ```bash
  flutter test integration_test/globe_camera_drag_test.dart
  flutter test integration_test/globe_camera_reset_test.dart
  flutter test integration_test/globe_camera_rotation_visual_test.dart
  ```
