# Implementation Plan - Interactive Camera Controls & Geographically Matched 3D Globe Visualization

This plan details the steps to align the 3D CustomPaint Globe visualization with the reference image: centering the camera perspective dynamically on the selected node, retrieving the 148 actual interface-to-interface links from the `instances` table in SQLite, locking satellites to geostationary positions, and drawing premium labels matching the reference style.

## Proposed Changes

### 1. Extract Full Interface-Based Topology Links & Node Names
* **File**: [`app_flutter/lib/domain/data_sources/sqlite_data_source.dart`](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/data_sources/sqlite_data_source.dart)
  * **Action**:
    1. In `fetchTopologyData()`, query the `instances` table for all rows of `type_name = 'interface'`.
    2. Parse the `data_json` field, extract the `description` string, and use a regular expression (`link to node\s+([\w\-]+)`) to identify the connected target node ID.
    3. Add these parsed connections as `TopologyLink` entries, capturing all 148 actual network link connections.
    4. Populate the `label` of the constructed `TopologyNode` using the `"name"` attribute inside the properties JSON payload (e.g. `"sat-1"`, `"microwave-node-sp_od"`) to match the display names.

### 2. Centering the camera coordinates on the Globe
* **File**: [`app_flutter/lib/features/topology/scene_3d_viewport.dart`](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
  * **Action**:
    1. Modify `_project` method signature to accept a dynamic `tilt` parameter instead of hardcoding `-0.3`.
    2. In `paint()`, calculate the base rotation and tilt using the camera's active geodetic coordinates:
       * `baseRotation = -_rad(widget.camera.longitude)`
       * `baseTilt = -_rad(widget.camera.latitude)`
       * `rotationAngle = baseRotation + userRotationX + (autoRotate ? animationValue * 2 * math.pi : 0.0)`
       * `tilt = baseTilt + userTilt`
    3. Pass this calculated `tilt` to all `_project` calls, centering the globe exactly on the focused active node's coordinates.

### 3. Geostationary Satellites Constellation
* **File**: [`app_flutter/lib/features/topology/scene_3d_viewport.dart`](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
  * **Action**: Set the orbital `speed = 0.0` for all satellite nodes. This makes the satellites geostationary relative to the rotating Earth, maintaining a stable constellation and preventing vertical drop lines and inter-satellite links from stretching across the sphere.

### 4. Premium Labels & HUD styling
* **File**: [`app_flutter/lib/features/topology/scene_3d_viewport.dart`](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
  * **Action**: When rendering node labels, paint a semi-transparent black rounded-rectangle capsule behind the text (like `sat-4`, `microwave-node-sp_od` in the reference image) to make them stand out.

---

## Verification Plan

### Manual Verification
1. **Camera Focus Alignment**: Tap on a node in the tree view (e.g. `CU-node-SP_OD`). Verify that the 3D globe rotates and tilts to center exactly on that node, aligning its label geographically with the CustomPaint landmass.
2. **constellation & Links**: Verify that satellites (`sat-1`, `sat-2`, `sat-3`, `sat-4`) are connected in space and link directly to ground stations with vertical dashed drop lines.
3. **Geostationary stability**: Verify that satellites rotate in lockstep with the globe, preserving links and constellation shape.
