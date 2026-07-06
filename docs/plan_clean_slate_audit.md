# Clean-Slate Audit Plan — Memory Safety on 6 FFI Files

**Skill:** adversarial-code-auditor v1.5, Path B
**Pillar:** Memory Safety
**Input:** 6 explicit file paths. Zero pre-existing bugs.

---

## Files to audit

| # | File | Lines | Focus |
|---|------|-------|-------|
| 1 | `cesium_native_bridge/src/bridge.cpp` | 150 | UAF, exception guards, handle overflow, c_str() lifetime |
| 2 | `cesium_native_bridge/src/resource_manager.cpp` | 19 | Signed wrap, malloc NULL, pointer provenance |
| 3 | `app_flutter/lib/domain/cesium_3d/cesium_engine.dart` | 157 | calloc/free pairing, checkStatus leaks, FFI string UAF |
| 4 | `app_flutter/lib/domain/cesium_3d/native/native_resource.dart` | 28 | NativeFinalizer detach:this, public pointer field |
| 5 | `app_flutter/lib/domain/cesium_3d/virtual_camera.dart` | 94 | NaN/Inf guards, range validation gaps, double equality |
| 6 | `app_flutter/lib/domain/cesium_3d/tile_fetcher.dart` | 164 | LRU eviction, socket drain, TOCTOU, OOM |

## Execution

1. **Dispatch 6 auditors** in parallel — one per file, clean-slate prompt
2. **Quality gate** — verify line citations, severity, UML, no false claims
3. **File findings** — `gh issue create --body-file` for every passed finding
4. **Dedup** — scan for same root cause across files
5. **Report** — save to `docs/audits/adversarial-audit-memory-safety-2026-07-07.md`

## Expected output

- 6-15 new issues filed with `bug` label
- 1 aggregate report
- Zero code changes

## Files modified by this plan

| File | Change |
|------|--------|
| `docs/audits/adversarial-audit-memory-safety-2026-07-07.md` | Created |
| GitHub issues | New issues filed |
| Source code | **None** |
