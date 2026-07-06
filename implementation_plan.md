# Implementation Plan — Unattended Backlog Debugging Loop

This plan details the end-to-end execution of the **Recursive Debugging Protocol** (`debug-protocol`) to systematically resolve the entire open bug backlog (Issues #58 through #141) in the workspace in a fully automated, unattended manner.

## User Review Required

> [!IMPORTANT]
> To enable complete unattended execution, the loop will run continuously without pausing for intermediate approvals. For each issue in the backlog:
> 1. We will automatically select the oldest open bug.
> 2. We will run the 8-step `debug-protocol` using context-isolated subagents to reproduce, diagnose, fix, test, and verify.
> 3. Fixes will be staged, committed, and pushed directly.
> 4. The issue will be commented on and closed dynamically.
> 5. The loop will immediately proceed to the next oldest open bug.

---

## Open Questions

* No open questions. The execution logic is defined by the `debug-protocol` skill and will run until the backlog is empty.

---

## Proposed Changes

We will systematically process the following open bug backlog in order of oldest to newest, executing targeted fixes on their corresponding files as identified by the Step 1 (Reproduction) and Step 3 (Investigation) subagents:

### Backlog Queue:
* **Issue #58**: 3D Geospatial Engine FFI Memory Leak and Infinite Loop Vulnerabilities
* **Issue #59**: Workspace Controls, Table Rendering, and Theme Compilation Failures
* **Issue #60**: Platform Initialization Crashes on Web and Hardcoded Path in FFI Tests
* **Issue #61**: Table View Sorting Crash, Swatch Misalignment, and Focus State Rebuilding Failures
* **Issue #62**: ChangeNotifier Disposal Notifications and Asynchronous Query Race Conditions
* **Issue #63**: Firebase Adapter Real-Time Stream Broadcast and Missing Query Realizations
* **Issue #64**: Unused projection rotation parameters in Scene3DViewport
* **Issue #65**: High text painter GC allocation churn in high-frequency rendering loop
* **Issue #66**: Unsynchronized frame updates via Timer.periodic in fly-to animation
* **Issue #67**: Redundant home click logic causing RangeError on empty tree
* **Issue #68**: Synchronous disk I/O on UI thread causing jank and web crash
* **Issue #69**: Zero-constraints splitter layout overflow in SplitWorkspace
* **Issue #70**: Color luminance contrast mismatch in SettingsPanel swatches
* **Issue #71**: Main UI Thread Blockage on Isolate Spawning Failure in BackgroundWorker
* **Issue #72**: Local-Only Stream Broadcasts in Firebase Adapter
* **Issue #73**: Redundant Network Scans and Discovery in Firebase Adapter
* **Issue #83**: Longitudinal Clamping in Virtual Camera (Anti-meridian Wall)
* **Issue #84**: Memory Leaks on FFI Error Conditions in CesiumEngine
* **Issue #85**: Use-After-Free Risk on Async FFI Strings in requestTileData
* **Issue #86**: Callback Failure in Tile Loading Interface
* **Issue #87**: Zero Test Coverage for CesiumEngine and FFI Bindings
* **Issue #88**: Redundant Configuration Loading in app.dart and layout.dart
* **Issue #89**: External View Updates Out of Sync with Sidebar Tree in Layout
* **Issue #90**: Fragile Map Type Casting in LayoutConfigService
* **Issue #91**: Asynchronous Race Condition on Concurrent Type Loading
* **Issue #92**: Erroneous TileCache Eviction during Duplicate Writes
* **Issue #93**: Lifetime Race on Deallocating Active BridgeState in C++ Bridge
* **Issue #94**: Assertion Failures inside cesium-native on Invalid Coordinates
* **Issue #95**: Hardcoded Starry Background Loop in Painter
* **Issue #96**: Abrupt Zoom Scale in Scale Gesture Detector
* **Issue #97**: UI Layout Overflow Risk in Header
* **Issue #98**: Double ScrollView Hierarchy for Panning
* **Issue #99**: Playback Time Index Wrap Precision Loss
* **Issue #100**: Sticky Expanded Ellipsis State in Breadcrumbs
* **Issue #101**: Bulky Breadcrumb Segments (ActionChip) Visual Presentation
* **Issue #102**: Split Workspace Pane Size Snapping and Non-Proportional Scaling
* **Issue #103**: Hardcoded Initial Active View blocks fallbacks
* **Issue #104**: Global Fallback State Mutation in TreeViewModel
* **Issue #105**: StateError on Watch Subscription in TablesViewModel
* **Issue #106**: Multi-Tab Rendering and Keeping Alive Bug in TabbedContainer
* **Issue #107**: GlobalKey Allocation Performance Issue in TreeViewModel
* **Issue #108**: Heavy Date Parsing inside Cell Build Method in TableViewWidget
* **Issue #109**: Redundant Repaint Boundaries in TableViewWidget
* **Issue #110**: Accessible Tap Target Size violation on Tree Node Toggle button
* **Issue #111**: Broken Swipe Animation in TabbedContainer
* **Issue #112**: Keyboard Holding (Key Repeat) Ignored in SidebarTree
* **Issue #113**: Hardcoded Mock Data Patterns Leaked into SQLite Queries
* **Issue #114**: Architectural Purity Violations (Circular/Leaked Dependencies) in Domain Layer
* **Issue #115**: Overly Restrictive Unique Constraint on Type Relations
* **Issue #116**: Regular Expression Re-compilation Performance Hotspot
* **Issue #117**: Redundant String Conversions in Validator
* **Issue #118**: Failed Map Type Casting on jsonDecode
* **Issue #119**: Dead Code: Obsolete AttributeDefinition Class
* **Issue #120**: Bare Asserts and Lack of Test Suite Wrapper in ffi_integration_test.dart
* **Issue #121**: Non-Isolated Unit/Widget Tests (Database FFI Dependency)
* **Issue #122**: Writing Untracked Files to the Repository Root in stress tests
* **Issue #123**: Pervasive 'as dynamic' Casting for Widget States in test suites
* **Issue #124**: Top-Level main() Entrypoint in Library File database_initializer.dart
* **Issue #125**: Swallowed Database Initializer Exceptions in RepositoryResolver
* **Issue #134**: NaN Check Bypass in VirtualCamera Constructor
* **Issue #135**: GPU/Native Memory Leak: Missing ui.Image Disposal
* **Issue #136**: Native Double-Free Vulnerability in NativeResource
* **Issue #138**: Decoded Tile Image Cache Capacity Thrashing
* **Issue #139**: Globe Navigation: Lack of Hierarchical Quadtree Fallback Rendering
* **Issue #140**: Globe Navigation: Redundant Main-Thread Image Decoding on Cache Misses
* **Issue #141**: Globe Navigation: Unthrottled Repaint Cycles (setState Storms)

---

## Verification Plan

### Automated Tests
* We will continuously run the unit and integration tests for verification:
  ```bash
  cd app_flutter && flutter test
  ```
* Every bug fix is verified by writing/extending test suites to cover the defect scenarios and ensuring they pass cleanly.
