# Round 2 Execution Plan — Memory Safety Audit

## Phase 0 — Coordinator Pre-flight
- Verify 6 target files exist on disk
- Query `gh issue list` confirming 14 known issues open (#60,#74,#75,#76,#77,#84,#85,#86,#87,#92,#93,#94,#134,#136)
- Stage /tmp/audit_r2/
- Wait for PROCEED

## Phase 1 — 6 Auditor Subagents (parallel, read-only)
Each receives: target file, 8-dimension review, 14 known issues, round 1 baseline, new-defect categories.
Output: ISSUE_TITLE:/ISSUE_BODY: blocks (7 sections), SEVERITY:, FILE_LOCATION:, separated by ---.
Known findings -> COMMENT_FOR_ISSUE:/COMMENT_BODY: blocks.
Piped to /tmp/audit_r2/auditor_output_1.txt through 6.txt.
3 retries per auditor. Coordinator never reads content.

A1: bridge.cpp — #74,#75,#76,#93,#94. New: lock ordering, handle overflow, error codes, double-shutdown, void* safety.
A2: resource_manager.cpp — #77. New: alignment, alloc(0) behavior, allocator interaction.
A3: cesium_engine.dart — #84,#85,#86,#87. New: NativeCallable, cross-isolate, dispose ordering, switch exhaustion.
A4: native_resource.dart — #136. New: GC-thread safety, pointer equality, SIMD alignment.
A5: virtual_camera.dart — #134. New: toStruct lifecycle, mutability race, serialization.
A6: tile_fetcher.dart — #92,#60. New: HttpClient reuse, timeout, cancellation, memory bound.

## Phase 2 — 1 Issue Filer Subagent (sequential)
Reads all 6 auditor outputs. Deduplication:
- "Confirms known issue [#N]" -> gh issue comment on #N
- "Extends [#N]" -> gh issue comment on #N
- "Discovered in audit" -> gh issue create --body-file
- COMMENT_FOR_ISSUE: -> gh issue comment --body-file

Verbatim temp file write. Char count verification. gh errors retried once.
Returns structured manifest: URLs, counts, verification status.

## Phase 3 — Coordinator Verification
Metadata-only: gh issue view --json state,labels,title.
Cross-reference duplicates. Write report to docs/audits/adversarial-audit-memory-safety-2026-07-06-r2.md.

## Content Firewall
Coordinator pipes without reading. Never touches bodies. Never reads issue bodies.
