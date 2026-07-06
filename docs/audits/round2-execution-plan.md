# Round 2 — Memory Safety Adversarial Audit Execution Plan

## Architecture: Three-Role Separation (SKILL.md v1.2)

```
COORDINATOR (you)
  │  Scope. Dispatch. Verify metadata only. NEVER touch issue content.
  │
  ├─ Phase 1: 6 AUDITOR SUBAGENTS (parallel, read-only)
  │    A1: bridge.cpp
  │    A2: resource_manager.cpp
  │    A3: cesium_engine.dart
  │    A4: native_resource.dart
  │    A5: virtual_camera.dart
  │    A6: tile_fetcher.dart
  │
  ├─ Phase 2: 1 ISSUE FILER SUBAGENT (sequential, after all A1–A6 return)
  │    Receives all 6 auditor outputs verbatim via temp files.
  │    Writes each body to temp file. Runs gh issue create / gh issue comment.
  │    Returns list of created URLs.
  │
  └─ Phase 3: COORDINATOR VERIFICATION
       Verifies issue count, label presence, section count via metadata.
       Produces aggregate report.
```

---

## Phase 0 — Coordinator Pre-flight

### 0.1 Confirm all 6 target files exist on disk
```
cesium_native_bridge/src/bridge.cpp
cesium_native_bridge/src/resource_manager.cpp
app_flutter/lib/domain/cesium_3d/cesium_engine.dart
app_flutter/lib/domain/cesium_3d/native/native_resource.dart
app_flutter/lib/domain/cesium_3d/virtual_camera.dart
app_flutter/lib/domain/cesium_3d/tile_fetcher.dart
```

### 0.2 Query all open known issues
```bash
gh issue list --repo gintatkinson/3dgs-002 --state open --limit 200 --json number,title,labels \\
  --jq '.[] | select(.number == 60 or .number == 74 or .number == 75 or .number == 76 or .number == 77 or .number == 84 or .number == 85 or .number == 86 or .number == 87 or .number == 92 or .number == 93 or .number == 94 or .number == 134 or .number == 136) | "\\(.number): \\(.title)"'
```
**Gate:** All 14 must be open. If any is closed/missing, stop and report.

### 0.3 Pre-stage temp directory
```bash
mkdir -p /tmp/audit_r2/
```

### 0.4 Output the PROCEED authorization prompt. Wait for human PROCEED.

**Gate:** Human must authorize before Phase 1 dispatch.

### Known Issues (14) — For Cross-Referencing

| Number | Title |
|--------|-------|
| #60 | Platform Initialization Crashes on Web and Hardcoded Path in FFI Tests |
| #74 | Use-After-Free / Mutex Dangling Pointer in C++ Bridge bridge_get_last_error |
| #75 | Silently Discarded Config Layout in C++ Bridge bridge_initialize |
| #76 | C++ Exception Propagation across FFI Boundary causing Dart VM Aborts |
| #77 | Signed Size Integer Wrap-around in C++ Bridge bridge_alloc |
| #84 | Memory Leaks on FFI Error Conditions in CesiumEngine |
| #85 | Use-After-Free Risk on Async FFI Strings in requestTileData |
| #86 | Callback Failure in Tile Loading Interface |
| #87 | Zero Test Coverage for CesiumEngine and FFI Bindings |
| #92 | Erroneous TileCache Eviction during Duplicate Writes |
| #93 | Lifetime Race on Deallocating Active BridgeState in C++ Bridge |
| #94 | Assertion Failures inside cesium-native on Invalid Coordinates |
| #134 | NaN Check Bypass in VirtualCamera Constructor |
| #136 | Native Double-Free Vulnerability in NativeResource |

---

## Phase 1 — Parallel File Audit (6 Auditor Subagents)

All 6 dispatched **simultaneously**. Each is isolated, read-only, and returns ONLY delimited output text. No file modification. No `gh` CLI access.

### 1.1 Common Inputs Given to Every Auditor Subagent

1. **Target pillar:** Memory Safety (weight HIGH)
2. **The 8-dimension review framework** (verbatim from SKILL.md):
   - 1) Context Understanding
   - 2) Correctness Analysis (Memory Safety weight HIGH)
   - 3) Security Review
   - 4) Performance Considerations
   - 5) Code Quality & Readability
   - 6) Architecture & Design
   - 7) Testing
   - 8) Documentation
3. **The complete known-issue list** (14 issues, for cross-referencing):
   `#60, #74, #75, #76, #77, #84, #85, #86, #87, #92, #93, #94, #134, #136`
4. **Output format specification** (see 1.2 below)
5. **Hard constraint:** Read-only. Do NOT modify files. Do NOT run `gh`. Return ONLY the delimited text output. No explanatory prose outside `ISSUE_TITLE:`/`ISSUE_BODY:` and `COMMENT_FOR_ISSUE:`/`COMMENT_BODY:` blocks.
6. **Instruction:** For every finding that is Critical or Important, produce a NEW issue-styled body (7 sections). For every finding that is Suggestion, produce a comment-styled body on the most relevant known issue. If a finding **confirms** or **extends** a known issue listed above, still produce the full 7-section body — the Issue Filer will decide whether to file it as a new issue or as a comment on the known issue based on Section 7.

### 1.2 Output Format Specification

Each auditor MUST separate findings with a blank line, then a `---` line, then a blank line.

**For Critical and Important findings:**
```
ISSUE_TITLE: [AUDIT] [<file_basename>]: <one-line finding description>

ISSUE_BODY:
## 1. Context and References
- **File**: `<repo_root_relative_path>:<line_range>`
- **Pillar**: Memory Safety
- **Symptom**: <observable failure caused by this defect>

## 2. Root Cause Analysis (5 Whys)
1. **Why ...?** Because ...
2. **Why ...?** Because ...
3. **Why ...?** Because ...
4. **Why ...?** Because ...
5. **Why ...?** Because ...

## 3. Correctness Analysis
<Detailed explanation — trace data flow, identify violated invariant, explain failure mode with concrete source line references.>

## 4. UML Diagrams (when applicable)
<Mermaid diagram if it clarifies the defect mechanics. Omit entire section if not applicable.>

## 5. Affected Callers / Downstream Impact
- `<Caller 1>` — <how it triggers or is affected>
- `<Caller 2>` — ...

## 6. Proposed Correction
<Code diff or snippet showing the fix.>

## 7. Relationship to Existing Issues
- **Confirms known issue** [#NNN] — <if this finding is already tracked>
- **Extends** [#NNN] — <if this adds new dimensions to a known issue>
- **Discovered in audit** — <if this is a brand new finding>

## Audit Source
Adversarial Memory Safety Audit — `docs/audits/adversarial-audit-memory-safety-2026-07-06-r2.md`

SEVERITY: Critical

FILE_LOCATION: <path>:<line>

---
```

**For Suggestions (comment body):**
```
COMMENT_FOR_ISSUE: #<target_issue_number>

COMMENT_BODY:
## Suggestion: <one-line description>
...
(Link back to audit source)

SEVERITY: Suggestion

FILE_LOCATION: <path>:<line>

---
```

### 1.3 Validity Rules (each auditor MUST satisfy)

- Every output block starts with exactly `ISSUE_TITLE:` or `COMMENT_FOR_ISSUE:` on its own line.
- Every `ISSUE_BODY:` block contains exactly 7 numbered sections (## 1. through ## 7.).
- The `## 7. Relationship to Existing Issues` section must include exactly ONE of: "Confirms known issue [#N]", "Extends [#N]", or "Discovered in audit".
- Every block has `SEVERITY:` line (one of: Critical, Important, Suggestion, Nitpick).
- Every block has `FILE_LOCATION:` line with a valid path:line reference.
- Block separator is `---` on its own line, surrounded by blank lines.

---

### 1.4 Auditor Subagent A1 — bridge.cpp

**Unique inputs:**

| Input | Value |
|-------|-------|
| File path | `cesium_native_bridge/src/bridge.cpp` |
| Known issues for this file | `#74, #75, #76, #93, #94` |
| Review doc | `docs/reviews/review_cpp_bridge.md` |

**Round 1 baseline (for awareness, do NOT re-report as new):**

5 Critical:
1. dangling `c_str()` in `bridge_get_last_error` after mutex unlock
2. `std::bad_alloc` from `bridge_initialize` escaping `extern "C"`
3. `bridge_shutdown` — mutex/map throw across FFI
4. `BridgeState` stored as `unique_ptr` — no lifetime extension for workers
5. `bridge_initialize` does not deep-copy tileset config — future UAF

2 Important:
1. 7 stub functions lack exception guards
2. coordinate transforms pass raw doubles without NaN/Inf validation

**New-finding categories to explore:**
(a) Additional stub functions not counted in the 7
(b) `g_statesMutex` lock ordering / deadlock risk
(c) `g_nextHandle` overflow/rollover
(d) missing `BRIDGE_ERR_*` error codes not enumerated
(e) the `bridge_handle_t` type width vs. pointer width mismatch
(f) double-`bridge_shutdown` crash
(g) any function accepting raw `void*` that could be fed a Dart-side freed pointer

**Expected output:** Detailed comment bodies for known issues. New issue bodies for any new Critical/Important findings.

---

### 1.5 Auditor Subagent A2 — resource_manager.cpp

**Unique inputs:**

| Input | Value |
|-------|-------|
| File path | `cesium_native_bridge/src/resource_manager.cpp` |
| Known issues for this file | `#77` |
| Review doc | `docs/reviews/review_cpp_bridge.md` |

**Round 1 baseline:**

3 Critical:
1. signed `int32_t size_bytes` wraps to SIZE_MAX on negative input
2. unchecked NULL return from `malloc` propagated to Dart
3. `bridge_free` accepts arbitrary pointers — double-free risk

2 Important:
1. no exception guard on `extern "C"` boundary
2. zero test coverage

**New-finding categories to explore:**
(a) `realloc` path if one existed (check if `bridge_realloc` exists or is planned)
(b) alignment issues — `malloc` returns 16-byte aligned on macOS but not guaranteed
(c) `bridge_alloc(0)` returning NULL vs. a valid pointer (platform variance)
(d) missing `bridge_memcpy` or `bridge_memset` that could cause buffer overflow
(e) integer overflow on add/multiply if a combined-alloc function exists
(f) interaction between `bridge_alloc`/`bridge_free` and the `BridgeState` in bridge.cpp (shared global allocator concerns)

**Expected output:** Full 7-section comment on #77. New issue bodies for any new findings.

---

### 1.6 Auditor Subagent A3 — cesium_engine.dart

**Unique inputs:**

| Input | Value |
|-------|-------|
| File path | `app_flutter/lib/domain/cesium_3d/cesium_engine.dart` |
| Known issues for this file | `#84, #85, #86, #87` |
| Review doc | `docs/reviews/review_geospatial.md` |

**Round 1 baseline:**

3 Critical:
1. UAF on `tileIdNative` — freed immediately after sync FFI call while native may use string async
2. memory leak in `getVisibleTileId` — `checkStatus` throws bypassing `calloc.free`
3. triple-fault in `requestTileData` — null callback + ignored return + UAF string

4 Important:
1. `getVisibleTileCount` same checkStatus-before-free leak
2. all `calloc` sites lack `try/finally`
3. null-pointer crash risk in `getVisibleTileId`
4. zero test coverage

**New-finding categories to explore:**
(a) `Pointer<Utf8>.fromFunction` / `NativeCallable` use (or misuse) in callback registration
(b) `receiveData` (if present) — buffer lifecycle across isolate boundaries
(c) `checkStatus` switch exhaustion — unknown error codes silently pass
(d) `String` to `Pointer<Utf8>` conversion using `.toNativeUtf8()` and its allocator
(e) multi-isolate access to `_bindings` / `_handle` — no lock
(f) `dispose()` shutdown ordering vs. pending FFI callbacks
(g) any `Pointer<NativeFunction>` passed as `void*` losing type safety

**Expected output:** Full 7-section comments on #84, #85, #86, #87. New issue bodies for new findings.

---

### 1.7 Auditor Subagent A4 — native_resource.dart

**Unique inputs:**

| Input | Value |
|-------|-------|
| File path | `app_flutter/lib/domain/cesium_3d/native/native_resource.dart` |
| Known issues for this file | `#136` |
| Review doc | `docs/reviews/review_geospatial.md` |

**Round 1 baseline:**

2 Critical:
1. `NativeFinalizer` with `detach: this` — finalizer callback races with `release()` causing double-free or silent leak
2. public `pointer` field — UAF possible after `release()`

3 Important:
1. no null check on `calloc` return
2. missing input validation on `count`/`elementSize`
3. no test for double-release or finalizer interaction

**New-finding categories to explore:**
(a) `NativeFinalizer` callback may be called on a GC thread — is it safe to call `calloc.free` there? (Dart 3.4+ allows it, check)
(b) `operator ==` and `hashCode` — does the object compare by identity or by pointer value? If by pointer, two wrappers to same native memory might be treated as different
(c) `copyWith` or clone semantics — shallow vs. deep copy of pointer
(d) missing `noSuchMethod` or forwarder that could accidentally dereference freed pointer
(e) alignment of allocated memory for SIMD types (Float64x2 etc.)

**Expected output:** Full 7-section comment on #136. New issue bodies for new findings.

---

### 1.8 Auditor Subagent A5 — virtual_camera.dart

**Unique inputs:**

| Input | Value |
|-------|-------|
| File path | `app_flutter/lib/domain/cesium_3d/virtual_camera.dart` |
| Known issues for this file | `#134` |
| Review doc | `docs/reviews/review_geospatial.md` |

**Round 1 baseline:**

2 Critical:
1. heading/pitch/roll lack ANY range validation before FFI boundary
2. altitude has no upper bound — `double.maxFinite` passes to native trig

3 Important:
1. `clamped` factory leaves heading/pitch/roll unclamped
2. `Cesium3DNative.updateViewport` constructs clamped camera then discards it — dead code
3. zero test coverage

**New-finding categories to explore:**
(a) `toNative()` or `toStruct()` conversion — does it use `malloc` / `calloc` with matching `free`?
(b) `copyWith` / mutability — is `VirtualCamera` properly immutable? If mutable, a race could modify fields mid-FFI-call
(c) `operator ==` and `hashCode` — floating-point equality for cameras is fragile
(d) missing `toString()` that exposes internal state — privacy concern for geolocation
(e) serialization to/from JSON — any buffer overflow or injection risk
(f) the `altitude` lower bound at -100m — is this documented and is -100m correct for all use cases (e.g., underwater, undersea cables)?
(g) `double.nan` / `double.infinity` handling in the `clamped` factory for _all_ fields, not just the clamped ones

**Expected output:** Full 7-section comment on #134. New issue bodies for new findings.

---

### 1.9 Auditor Subagent A6 — tile_fetcher.dart

**Unique inputs:**

| Input | Value |
|-------|-------|
| File path | `app_flutter/lib/domain/cesium_3d/tile_fetcher.dart` |
| Known issues for this file | `#92, #60` |
| Review doc | `docs/reviews/review_geospatial.md` |

**Round 1 baseline:**

2 Critical:
1. duplicate write eviction in `put()` — evicts LRU even when key already exists
2. TCP socket leak — non-200 response stream not drained, exhausts OS sockets

Suggestions:
- `put()` doesn't promote to MRU
- TOCTOU race on same-key fetch
- no `maxSize: 0` validation

**New-finding categories to explore:**
(a) `HttpClient` reuse — is a new client created per fetch or reused? If reused, connection pool exhaustion
(b) `HttpClient` `badCertificateCallback` — does it accept all certs? MITM risk
(c) `fetchTile` timeout — is there one? If not, slow server ties up connection forever
(d) `cancelFetch` / cancellation token — no way to abort in-flight fetches when disposing
(e) concurrent `put()` calls — `_map` is a plain `LinkedHashMap` with no synchronization
(f) `_cache.clear()` in eviction path — is the entire cache cleared or just one entry? Check
(g) `Uint8List` memory — each tile is held as `Uint8List` in the cache; total memory bound is not enforced (only entry count is), could OOM with large tiles
(h) error responses (4xx/5xx) exceptions should be caught — currently they propagate as unhandled futures

**Expected output:** Full 7-section comments on #92 and #60. New issue bodies for new findings.

---

### 1.10 Phase 1 Error Handling

For each auditor subagent that:

- **Crashes or returns empty output:** Re-dispatch exactly the same subagent with identical inputs. Mark as attempt N+1. If 3 consecutive failures for the same file, escalate to coordinator — the coordinator must hand-audit that single file as fallback (but must still produce the same delimited output format and pass it through the Issue Filer).
- **Returns output missing required markers** (no `ISSUE_TITLE:`, no `---` separators, fewer than 7 sections in a body): Re-dispatch with a stronger prompt emphasizing the exact output format and providing a COMPLETE example with dummy content.
- **Returns findings that are clearly already covered by a known issue** (e.g., a new issue for `c_str()` dangling when #74 already covers it): The Issue Filer will catch this via Section 7 and file it as a comment instead. No re-dispatch needed.
- **Returns output that combines multiple findings into one block** (e.g., one `ISSUE_BODY:` describes 3 different bugs): Re-dispatch with instruction to produce one block per distinct root cause.

### 1.11 Phase 1 Output Capture Mechanism

As each auditor subagent returns, the coordinator:
1. Pipes the raw output into `/tmp/audit_r2/auditor_output_<filenum>.txt` **without reading it**:
   ```bash
   cat > /tmp/audit_r2/auditor_output_1.txt
   [paste raw auditor A1 output here — do not edit]
   ^D
   ```
2. Records as "captured" in a manifest file:
   ```bash
   echo "auditor_output_1.txt captured at $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> /tmp/audit_r2/manifest.txt
   ```
3. Does NOT read, grep, summarize, or inspect the content of any captured file.

---

## Phase 2 — Issue Filer Subagent

### 2.1 Overview

Dispatched AFTER all 6 auditors return. Receives ALL auditor outputs as raw text. The ONLY role that touches `gh`.

### 2.2 Issue Filer Inputs

1. **The repository:** `gintatkinson/3dgs-002`
2. **The label to apply to new issues:** `bug`
3. **The 14 known issue numbers** (for deduplication): `#60, #74, #75, #76, #77, #84, #85, #86, #87, #92, #93, #94, #134, #136`
4. **The 6 auditor output files** with instructions to read them verbatim from `/tmp/audit_r2/auditor_output_1.txt` through `/tmp/audit_r2/auditor_output_6.txt`
5. **Strict instructions:**
   - Read ALL 6 auditor output files into memory.
   - Parse each file to extract `ISSUE_TITLE:`/`ISSUE_BODY:` pairs and `COMMENT_FOR_ISSUE:`/`COMMENT_BODY:` pairs.
   - **Verbatim rule:** The body text between `ISSUE_BODY:` and the next `---` separator MUST be written to the temp file EXACTLY as-is. No character may be added, removed, or changed. If the Issue Filer changes even one character, the audit is invalid.
   - **Do NOT audit code. Do NOT rewrite findings. Do NOT summarize.**
   - The only modification allowed is stripping the `ISSUE_BODY:` header line (the literal string `ISSUE_BODY:`) before writing to temp file — everything after that header, including blank lines, is the body.
   - The `ISSUE_TITLE:` value goes to `--title` verbatim.
   - **`gh` CLI only.** No other tools for filing.

### 2.3 Deduplication Logic (Issue Filer)

For each `ISSUE_TITLE:`/`ISSUE_BODY:` pair:

1. Parse Section 7 ("Relationship to Existing Issues") from the body.

2. If Section 7 contains:
   - **"Confirms known issue [#NNNNN]"**: FILE AS A COMMENT on issue #NNNNN using `gh issue comment`. Write the full body to a comment temp file.
   - **"Extends [#NNNNN]"**: FILE AS A COMMENT on issue #NNNNN using `gh issue comment`. Write the full body to a comment temp file.
   - **"Discovered in audit"**: FILE AS A NEW ISSUE using `gh issue create`.

3. For each `COMMENT_FOR_ISSUE:`/`COMMENT_BODY:` pair:
   - FILE AS A COMMENT on the target issue number using `gh issue comment`.

4. **Duplicate guard:** Before creating a NEW issue, check: does the title / file-location / root-cause match ANY previously created issue in THIS batch? If yes, skip it (the auditor produced a duplicate within its own output). Log the skip to `/tmp/audit_r2/skipped_duplicates.txt`.

5. **Known-issue guard (HARD):** Before creating any NEW issue, verify the finding does NOT reference any of the 14 known issue numbers in Section 7 as "Confirms" or "Extends". If it does, downgrade it to a COMMENT instead.

### 2.4 Exact Command Templates

**For NEW issues:**
```bash
# Step 1: Write body to temp file using heredoc (unquoted delimiter so no variable expansion)
cat > /tmp/gh_body_<UNIQUE_SEQ>.md << 'ENDOFFILE'
<exact body text from ISSUE_BODY: marker onward — no editing, no trimming>
ENDOFFILE

# Step 2: Verify char count matches auditor output
ORIGINAL_CHARS=<character count of body from auditor output>
FILE_CHARS=$(wc -c < /tmp/gh_body_<UNIQUE_SEQ>.md | tr -d ' ')
if [ "$ORIGINAL_CHARS" != "$FILE_CHARS" ]; then
  echo "FATAL: char count mismatch for issue <UNIQUE_SEQ>. Original=$ORIGINAL_CHARS File=$FILE_CHARS"
  exit 1
fi

# Step 3: Create issue
gh issue create \
  --repo gintatkinson/3dgs-002 \
  --title "<exact ISSUE_TITLE value>" \
  --label "bug" \
  --body-file /tmp/gh_body_<UNIQUE_SEQ>.md

# Step 4: Capture URL from stdout
# Expected: https://github.com/gintatkinson/3dgs-002/issues/<NUMBER>
```

**For COMMENTS:**
```bash
# Step 1: Write comment body to temp file
cat > /tmp/gh_comment_<UNIQUE_SEQ>.md << 'ENDOFFILE'
<exact comment body text — no editing>
ENDOFFILE

# Step 2: Verify char count
ORIGINAL_CHARS=<character count>
FILE_CHARS=$(wc -c < /tmp/gh_comment_<UNIQUE_SEQ>.md | tr -d ' ')
if [ "$ORIGINAL_CHARS" != "$FILE_CHARS" ]; then
  echo "FATAL: char count mismatch for comment <UNIQUE_SEQ>"
  exit 1
fi

# Step 3: Post comment
gh issue comment <ISSUE_NUMBER> \
  --repo gintatkinson/3dgs-002 \
  --body-file /tmp/gh_comment_<UNIQUE_SEQ>.md
```

### 2.5 Issue Filer Output Manifest

```
Filer Manifest — Round 2 Audit
===============================
Filed at: <ISO timestamp>

NEW ISSUES CREATED:
[<seq>] <issue_url> | Title: <title> | Severity: <severity> | CharCount: <N> matched
...

COMMENTS POSTED:
[<seq>] <issue_url>#<comment_id> | On: #<target_issue> | CharCount: <N> matched
...

SKIPPED (duplicates):
[<seq>] <reason> | Title: <title>
...

VERIFICATION:
Total new issues: <N>
Total comments posted: <N>
All char counts matched: YES/NO
All return codes zero: YES/NO
```

### 2.6 Phase 2 Error Handling

- If `gh` returns non-zero: Retry once with 5s delay. If still fails, log to `/tmp/audit_r2/gh_errors.txt` and continue with next filing. Do NOT halt the batch.
- If char count verification fails: Log the mismatch, do NOT file the issue, continue to next. Report in manifest.
- If temp file write fails (disk full): Clean up existing temp files, report error, halt.
- If an ISSUE_BODY is malformed (missing sections): Still file it but flag in manifest as "BODY_INCOMPLETE_SECTIONS=<count_of_7>".
- If an ISSUE_TITLE / ISSUE_BODY pair cannot be parsed (no title, body starts mid-sentence): Skip it. Log preamble to `/tmp/audit_r2/unparseable.txt`. Do NOT guess or invent content.

---

## Phase 3 — Coordinator Verification

### 3.1 Verify Filed Issues (metadata only)

For every URL in the filer manifest's "NEW ISSUES CREATED" list:

```bash
gh issue view <ISSUE_NUMBER> --repo gintatkinson/3dgs-002 --json title,labels,state,url
```

Checks:
- `state` is `"OPEN"` for every filed issue.
- `labels` contains `"bug"` for every filed issue.
- The `title` starts with `[AUDIT]` for every filed issue.
- Total count of new issues matches the manifest's "Total new issues" count.

**The coordinator MUST NOT run `gh issue view --json body`** (which would read body content). Verification is metadata-only.

### 3.2 Verify Comments (metadata only)

Record baseline comment counts pre-filing. Delta should match comments posted per-issue.

### 3.3 Coarse Content Verification (without reading bodies)

1. Every `CharCount` entry says "matched" (no mismatch flags in manifest).
2. Every filing entry has a numeric char count > 100 (sanity check that bodies aren't empty).

If any mismatch is found, re-dispatch Issue Filer with ONLY the failed entries.

### 3.4 Cross-Reference Deduplication Scan

Check manifest for:
- Multiple new issues filed against the same `FILE_LOCATION` → close duplicate, comment on canonical.
- Any new issue whose title matches a known issue's root cause → close duplicate, comment on canonical.

### 3.5 Produce Aggregate Report

Write to `docs/audits/adversarial-audit-memory-safety-2026-07-06-r2.md`:

```markdown
# Adversarial Audit Report — Memory Safety — 2026-07-06 (Round 2)

## Scope
- Risk pillar(s) audited: Memory Safety
- Source files audited: 6
- Open issues in cluster before audit: 14
- New issues filed: P

## Findings by Severity
- Critical: X
- Important: Y
- Suggestion: Z

## Per-File Summary
| File | Critical | Important | Suggestion | Nitpick | New Issues |
|---|---|---|---|---|---|
| `bridge.cpp` | ... | ... | ... | ... | ... |
| ... | | | | | |

## Cross-Cutting Patterns
- [Pattern 1: description, files affected, canonical issue]
- [Pattern 2: ...]

## Recommended Remediation Priority
1. [Highest-priority finding]
2. [...]
```

---

## Content Firewall Enforcement

| Coordinator Action | Allowed? | Mechanism |
|---|---|---|
| Dispatch auditor subagents with file paths and instructions | YES | Required |
| Read auditor output before writing to /tmp | NO | Pipe directly via `cat >` without displaying content |
| Grep auditor output for `ISSUE_TITLE:` to confirm format validity | NO | Issue Filer validates format; coordinator validates only final manifest |
| Summarize or filter auditor findings | NO | Forbidden by HARD CONSTRAINT |
| Count the number of `---` separators in auditor output (coarse signal) | YES | `grep -c '^---$' /tmp/audit_r2/auditor_output_N.txt` counts blocks without reading content |
| Verify that filed issues exist and are open | YES | `gh issue view --json state` |
| Read issue body to verify section count | NO | Issue Filer verifies sections; coordinator trusts the filer manifest |
| Edit the Issue Filer's temp files before `gh` runs | NO | Forbidden |

---

## Complete Sequencing

```
  Time ──────────────────────────────────────────────────────────>

  Phase 0    Phase 1 (parallel)    Phase 2 (sequential)   Phase 3
  ┌──────┐   ┌─────────────────┐   ┌──────────────────┐   ┌──────────┐
  │Coord │   │  A1 (bridge)    │   │                  │   │ Verify   │
  │pre-  │   │  A2 (resrc)     │   │  Issue Filer     │   │ metadata │
  │flight│   │  A3 (engine)    │──>│  reads all 6     │──>│ check    │
  │      │   │  A4 (native)    │   │  outputs, files  │   │ manifest │
  │PROCEED   │  A5 (camera)    │   │  issues+comments │   │ produce  │
  │gate  │   │  A6 (tile)      │   │  returns manifest│   │ report   │
  └──────┘   └─────────────────┘   └──────────────────┘   └──────────┘

  Gate:      All complete           All captured           Report saved
  Human says (wait for last to      (sequential, must      to docs/audits/
  "PROCEED"  finish before          run after Phase 1)     
             Phase 2 dispatch)
```
