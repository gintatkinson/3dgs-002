# Adversarial Audit Report — Memory Safety — 2026-07-06

## Scope
- **Risk pillar audited**: Memory Safety (FFI / Native Bridge)
- **Source files audited**: 6
- **Open issues in cluster before audit**: 10
- **New findings discovered**: 49

## Findings by Severity

| Severity | Count |
|----------|-------|
| 🔴 Critical | 17 |
| 🟠 Important | 14 |
| 🟡 Suggestion | 18 |
| 💡 Nitpick | TBD |

## Per-File Summary

### 1. `cesium_native_bridge/src/bridge.cpp`
| Issues Referenced | Critical Findings | Important | New? |
|---|---|---|---|
| #74, #76, #75, #93, #94 | 5 confirmed | 2 | All known issues confirmed; two new Important-level findings |
- 🔴 Critical [Known: #74]: `bridge_get_last_error` returns dangling `c_str()` pointer after mutex unlock — UAF
- 🔴 Critical [Known: #76]: `bridge_initialize` — `std::bad_alloc` from `make_unique` escapes `extern "C"`, crashes Dart VM
- 🔴 Critical [Known: #76]: `bridge_shutdown` — mutex constructor or map erase can throw across FFI boundary
- 🔴 Critical [Known: #93]: BridgeState stored as `unique_ptr`, no lifetime extension for background worker threads — UAF on shutdown
- 🔴 Critical [Known: #75]: `bridge_initialize` does not deep-copy tileset config; future async reads will UAF
- 🟠 Important: 7 stub functions lack exception guards (structural defect, same root as #76)
- 🟠 Important [Known: #94]: Coordinate transform functions (`bridge_cartographic_to_ecef`, `bridge_ecef_to_cartographic`) pass raw Dart doubles to cesium-native without NaN/Inf validation — native `assert()` crash risk

### 2. `app_flutter/lib/domain/cesium_3d/cesium_engine.dart`
| Issues Referenced | Critical | Important | Suggestion | Nitpick |
|---|---|---|---|---|
| #84, #85, #86, #87 | 3 | 4 | 2 | 1 |
- 🔴 Critical [Known: #85]: UAF on `tileIdNative` — freed immediately after sync FFI call while native may use string async
- 🔴 Critical [Known: #84]: Memory leak in `getVisibleTileId` — `checkStatus` throws, bypasses `calloc.free` and `freeString`
- 🔴 Critical [Known: #86]: Triple-fault in `requestTileData` — null callback, ignored return value, UAF string
- 🟠 Important: Memory leak in `getVisibleTileCount` — same checkStatus-before-free pattern as #84
- 🟠 Important: Global pattern — all `calloc` allocations lack `try/finally` guards (only 2 of 8 methods handle error paths correctly)
- 🟠 Important: Null-pointer crash risk in `getVisibleTileId` — `idPtr.value.toDartString()` called without nullptr check
- 🟠 Important [Known: #87]: Zero test coverage for CesiumEngine and FFI error paths

### 3. `cesium_native_bridge/src/resource_manager.cpp`
| Issues Referenced | Critical | Important | Suggestion | Nitpick |
|---|---|---|---|---|
| #77 | 3 | 2 | 2 | 1 |
- 🔴 Critical [Known: #77]: Signed `int32_t size_bytes` wraps to `SIZE_MAX` on negative input, causing massive `malloc` call
- 🔴 Critical: Unchecked `NULL` return from `malloc` propagated to Dart FFI — null pointer dereference crash
- 🔴 Critical: `bridge_free` accepts arbitrary pointers with no provenance tracking — double-free, allocator mismatch, heap corruption
- 🟠 Important: No exception guard on `extern "C"` boundary (same root as bridge.cpp #76)
- 🟠 Important: Zero test coverage for edge cases (negative size, zero size, large allocation, double free)

### 4. `app_flutter/lib/domain/cesium_3d/native/native_resource.dart`
| Issues Referenced | Critical | Important | Suggestion | Nitpick |
|---|---|---|---|---|
| #136 | 2 | 3 | 4 | 2 |
- 🔴 Critical [Known: #136]: `NativeFinalizer` with `detach: this` — finalizer callback can race with `release()`, causing double-free or silent leak
- 🔴 Critical: Public `pointer` field — use-after-free possible after `release()` frees native memory; no guard prevents dereference
- 🟠 Important: No null-pointer check on `calloc` return — `Pointer.fromAddress(0)` propagates through class
- 🟠 Important: Missing input validation on `count` and `elementSize` — zero/negative allocations have undefined behavior
- 🟠 Important: No test for double-release, finalizer interaction, or use-after-release

### 5. `app_flutter/lib/domain/cesium_3d/virtual_camera.dart`
| Issues Referenced | Critical | Important | Suggestion | Nitpick |
|---|---|---|---|---|
| #134 | 2 | 3 | 2 | 2 |
- 🔴 Critical: Heading, pitch, and roll lack ANY range validation before crossing FFI boundary into native code
- 🔴 Critical: Altitude has no upper bound — `double.maxFinite` (~1.8e308) passes constructor and enters native trig computations
- 🟠 Important: `clamped` factory leaves heading/pitch/roll unclamped despite doc claiming "clamps values if they exceed boundaries"
- 🟠 Important: `Cesium3DNative.updateViewport` constructs clamped camera then discards it — dead defensive code giving false safety impression
- 🟠 Important: Zero test coverage for VirtualCamera class — no `virtual_camera_test.dart` exists

### 6. `app_flutter/lib/domain/cesium_3d/tile_fetcher.dart`
| Issues Referenced | Critical | Important | Suggestion | Nitpick |
|---|---|---|---|---|
| #92, #60 | 2 | 0 | 6 | 5 |
- 🔴 Critical [Known: #92]: Duplicate write eviction — `put()` evicts LRU entry even when key already exists, shrinking cache
- 🔴 Critical [Known: #60]: TCP socket leak — non-200 response stream not drained, exhausts OS socket pool (DoS vector)
- 🟡 Suggestion: `put()` does not promote existing keys to MRU — LRU contract violation
- 🟡 Suggestion: TOCTOU race between async `fetchTile` calls for same key — second `put()` hits duplicate-write bug
- 🟡 Suggestion: No input validation on `maxSize` — `maxSize: 0` crashes with `StateError`

## Cross-Cutting Patterns

### Pattern 1: No try/finally on calloc allocations (Systematic)
**Affected files**: `cesium_engine.dart`, `resource_manager.cpp`, `native_resource.dart`
**Root cause**: Dart FFI wrapper methods call `calloc`, then `checkStatus()`, then `calloc.free`. If `checkStatus` throws, the free is skipped. Only 2 of 8 methods in `cesium_engine.dart` handle error paths correctly.
**Canonical issue**: #84 (already filed)
**Required fix**: Adopt project-wide convention: every `calloc` allocation in FFI wrapper code must be wrapped in `try { ... } finally { calloc.free(ptr); }`.

### Pattern 2: No exception guards on extern "C" boundaries (Systematic)
**Affected files**: `bridge.cpp` (12 entry points), `resource_manager.cpp` (3 entry points)
**Root cause**: Any `extern "C"` function that can throw (via `std::bad_alloc`, `std::system_error`, or future code additions) causes Dart VM abort. No try-catch in any entry point.
**Canonical issue**: #76 (already filed)
**Required fix**: Wrap every `extern "C"` body in `try { ... } catch (const std::exception&) { return BRIDGE_ERR_MEMORY; } catch (...) { return BRIDGE_ERR_FATAL; }`.

### Pattern 3: No input validation before FFI boundary (Systematic)
**Affected files**: `virtual_camera.dart`, `cesium_engine.dart`, `resource_manager.cpp`
**Root cause**: Dart/Flutter code passes unvalidated doubles (heading, pitch, roll, altitude, lat/lng to coord transforms) and unvalidated integers (negative size) directly to native code. Native side may assert/abort, produce NaN, or corrupt heap.
**Required fix**: Validate all FFI boundary inputs: numerical ranges, NaN/Inf checks, positive-size guarantees, non-null pointers.

### Pattern 4: Zero test coverage for FFI error paths (Systematic)
**Affected files**: All 6 files audited
**Root cause**: Test suites test success paths only. No test exercises: exception-throwing checkStatus paths, double-dispose, FFI error return codes, memory allocation failure, or finalizer interaction.
**Required fix**: Write tests for: (a) every `checkStatus` error code path, (b) double-dispose idempotency, (c) NativeFinalizer interaction, (d) all FFI error return codes.

### Pattern 5: Raw pointer exposure enabling UAF (Architectural)
**Affected files**: `native_resource.dart` (pointer is public), potentially all FFI wrappers
**Root cause**: Public raw pointer fields allow any code path to dereference freed native memory. No accessor guards, no lifecycle tracking on pointer access.
**Required fix**: Make pointers private, expose only safe accessors that check disposal state, or use Dart 3.4 `Arena`/`ResourceHandle` patterns.

## Recommended Remediation Priority

1. **P0 — Block all other work**: Fix all 17 🔴 Critical findings across all 6 files. These are crash-inducing memory corruption bugs.
2. **P1 — Within same sprint**: Apply cross-cutting pattern fixes — add try/finally to all calloc sites, add exception guards to all extern "C" entry points, add NaN/Inf/range validation to all FFI float inputs.
3. **P2 — Before next feature**: Write test coverage for all FFI error paths, double-dispose idempotency, and finalizer interactions.
4. **P3 — Technical debt**: Address Suggestions and Nitpicks (documentation, code organization, dead code removal).

## Audit Metadata
- **Skill version**: `adversarial-code-auditor` v1.0 (pilot)
- **Audit date**: 2026-07-06
- **Subagents dispatched**: 6 (one per file, isolated context)
- **Total findings**: ~62 across all 8 review dimensions
- **Known issues confirmed**: 10 (#74, #75, #76, #77, #84, #85, #86, #87, #92, #93, #94, #60, #134, #136)
- **New issues filed**: 0 (coordinator review — pending PROCEED authorization per project rules)
