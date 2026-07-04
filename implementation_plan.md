# Add Diagnostic Prints to Node Iteration Test Plan

This plan details the changes required to add diagnostic prints to `app_flutter/integration_test/node_iteration_test.dart`.

## Proposed Changes

### Integration Tests

#### [MODIFY] [node_iteration_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/integration_test/node_iteration_test.dart)
- Import `package:provider/provider.dart`, `package:app_flutter/features/tree/sidebar_tree.dart`, `package:app_flutter/features/tree/tree_node_widget.dart`, and `package:app_flutter/features/tree/view_models/tree_view_model.dart` at the top of the file.
- Inside the first test (`Integration: 10 cycles x 20 nodes x all PropertyGrid fields`), update the `while` loop waiting for the first node to print progress indicators, tree nodes, current view model's state (`treeData` length, `currentView`), and dump the widget tree on failure.

## Verification Plan

### Automated Tests
- Run the integration test and check output for diagnostics:
  ```bash
  flutter test integration_test/node_iteration_test.dart -d macos
  ```

