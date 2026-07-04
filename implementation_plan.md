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
