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

We will systematically process the following open bug backlog in order of oldest to newest, executing targeted fixes on their corresponding files:

### Backlog Queue:
* **Issue #58**: 3D Geospatial Engine FFI Memory Leak and Infinite Loop Vulnerabilities [CLOSED]
* **Issue #59**: Workspace Controls, Table Rendering, and Theme Compilation Failures [ACTIVE]
  - File: `app_flutter/lib/features/properties/property_grid.dart`
    - Update `DropdownButtonFormField` (around line 718) to replace `initialValue: value` with `value: value` to resolve the compilation error.
  - File: `app_flutter/lib/features/tables/table_view_widget.dart`
    - Update `_DataCell` (around line 389) to size itself using `columnModel.width ?? colWidth` instead of hardcoding `colWidth`, resolving the column alignment layout mismatch with headers.
    - Update table sorting logic (around lines 81-82) to map `_sortColumnIndex!` (visible header index) to its corresponding absolute index in `allHeaders` (or `headerIndices`) before accessing row values, correcting sorting behaviour when columns are hidden.
    - Update `_HeaderRow` container decoration (around line 195) to include `color: Theme.of(context).colorScheme.surface` to give it a solid background color and prevent scrolled rows from showing through.
  - File: `app_flutter/test/layout_test.dart` or new test file
    - Add tests/verify that table columns align and sorting maps to the correct column when columns are hidden.
* **Issue #60**: Platform Initialization Crashes on Web and Hardcoded Path in FFI Tests
* **Issue #61**: Table View Sorting Crash, Swatch Misalignment, and Focus State Rebuilding Failures
* **Issue #62**: ChangeNotifier Disposal Notifications and Asynchronous Query Race Conditions
* **Issue #63**: Firebase Adapter Real-Time Stream Broadcast and Missing Query Realizations
* ... [rest of backlog issues #64 to #141]

---

## Verification Plan

### Automated Tests
* We will continuously run the unit and integration tests for verification:
  ```bash
  cd app_flutter && flutter test
  ```
* Every bug fix is verified by writing/extending test suites to cover the defect scenarios and ensuring they pass cleanly.
