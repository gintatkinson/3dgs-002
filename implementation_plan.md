# Implementation Plan - Interactive Camera Controls & DB-Backed Topology on 3D Globe

This plan details the steps to implement interactive camera gestures (pan/rotate and zoom) for the 3D Globe and retrieve active node and link topology dynamically from the local SQLite database instead of using static template assets.

## Proposed Changes

### 1. Implement Interactive Navigation Controls
- **File**: [`app_flutter/lib/features/topology/scene_3d_viewport.dart`](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart)
- **Action**: Wrap the `CustomPaint` widget inside the `build` method of `_Scene3DViewportState` in a `GestureDetector` and `Listener`:
  - **Panning / Rotation**:
    - Listen to `onPanUpdate` to dynamically update the camera's `latitude` and `longitude` coordinates based on drag offsets.
    - Damping will be applied to keep the drag-to-rotate interaction smooth.
  - **Zooming**:
    - Listen to `onPointerSignal` (catching `PointerScrollEvent`) to adjust the camera's `altitude` dynamically (clamped to a safe minimum/maximum range).
  - **Auto-Rotation Control**:
    - Add an interactive "Auto-Rotate" switch in the Map Configuration panel to toggle the automatic rotation animation.

### 2. Populate Nodes Dynamically from the Database
- **File**: [`app_flutter/lib/domain/data_source.dart`](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/data_source.dart)
  - **Action**: Add abstract method declaration `fetchTopologyData` and import the topology model.
- **File**: [`app_flutter/lib/domain/data_sources/sqlite_data_source.dart`](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/data_sources/sqlite_data_source.dart)
  - **Action**: Implement `fetchTopologyData` by querying the `properties` table, decoding JSON, extracting geolocation, and creating node/link structures.
- **File**: [`app_flutter/lib/domain/data_sources/firebase_data_source.dart`](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/data_sources/firebase_data_source.dart)
  - **Action**: Implement a dummy `fetchTopologyData` returning empty topology data to conform to the interface.
- **File**: [`app_flutter/lib/features/layout/layout.dart`](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/layout/layout.dart)
  - **Action**: In `_preloadTopologyData()`, query the database via the active `DataSource` to retrieve physical nodes, falling back to asset loading if no nodes are found.
- **Files**:
  - [`app_flutter/test/features/tables/data_table_benchmark_test.dart`](file:///Users/perkunas/jail/3dgs-002/app_flutter/test/features/tables/data_table_benchmark_test.dart)
  - [`app_flutter/test/features/tables/table_view_widget_test.dart`](file:///Users/perkunas/jail/3dgs-002/app_flutter/test/features/tables/table_view_widget_test.dart)
  - [`app_flutter/test/features/tables/view_models/tables_view_model_test.dart`](file:///Users/perkunas/jail/3dgs-002/app_flutter/test/features/tables/view_models/tables_view_model_test.dart)
  - **Action**: Implement dummy `fetchTopologyData` in mock data sources to satisfy the updated `DataSource` interface contract.



---

## Verification Plan

### Manual Verification
1. **Interactive Panning**: Click and drag on the 3D globe. Verify that it pans and rotates in sync with the drag direction.
2. **Scroll Zooming**: Use the mouse scroll wheel on the globe. Verify that it zooms in and out.
3. **Auto-Rotation Toggle**: Toggle the "Auto-Rotate" setting in the config panel and verify it pauses/starts the automatic rotation.
4. **Real Database Nodes**: Verify that actual network devices loaded from the database are drawn on the globe.
