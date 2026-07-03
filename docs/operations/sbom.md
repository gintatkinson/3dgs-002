# Software Bill of Materials (SBOM)

> Generated: 2026-06-30
> Project: Digital Pipeline Platform (app_flutter)

## Direct Dependencies

| Package | Version | License | Purpose | Notes |
|---------|---------|---------|---------|-------|
| flutter | 3.44.0 | BSD-3-Clause | UI framework | SDK dependency |
| provider | 6.1.5+1 | MIT | State management | |
| sqflite_common_ffi | 2.4.2 | BSD-2-Clause | Local SQLite persistence | |
| path_provider | 2.1.6 | BSD-3-Clause | Filesystem paths | |
| path | 1.9.1 | BSD-3-Clause | Path manipulation | |
| flex_color_scheme | 8.4.0 | BSD-3-Clause | Theme system | |
| shared_preferences | 2.5.5 | BSD-3-Clause | Local key-value storage | |
| firebase_core | 4.11.0 | BSD-3-Clause | Firebase initialization | |
| cloud_firestore | 6.6.0 | BSD-3-Clause | Remote persistence | Type errors in build/ excluded from analysis; no compatible newer version |
| firebase_auth | 6.5.4 | BSD-3-Clause | Firebase authentication | |
| cupertino_icons | 1.0.9 | MIT | iOS-style icons | |
| flutter_test | 3.44.0 | BSD-3-Clause | Testing framework | Dev dependency |
| integration_test | 3.44.0 | BSD-3-Clause | Integration testing | Dev dependency |
| flutter_lints | 6.0.0 | BSD-3-Clause | Lint rules | Dev dependency |

## Transitive Dependencies (key)

| Package | Version | Notes |
|---------|---------|-------|
| sqlite3 | 3.3.3 | Underlying SQLite engine for sqflite_common_ffi |
| matcher | 0.12.19 | Locked by Flutter SDK |
| meta | 1.18.0 | Locked by Flutter SDK |
| test_api | 0.7.11 | Locked by Flutter SDK |
| _flutterfire_internals | 1.3.73 | Shared Firebase internals |
| sqflite_common | 2.5.11 | Shared sqflite internals |

## Dependency Decisions

### Locked transitive deps
The following packages are pinned by the Flutter SDK and cannot be independently upgraded:
- `meta`, `package_config`, `vector_math`, `matcher`, `test_api`, `leak_tracker`
- These update when the Flutter SDK is upgraded.

### Known compatibility issues
- `cloud_firestore 6.6.0` has `argument_type_not_assignable` errors with Dart 3.12 strict type system (strict-casts, strict-inference, strict-raw-types enabled in `analysis_options.yaml`).
- Mitigation: `build/` excluded from `flutter analyze` (third-party source packages only).
- None affect production builds with `flutter build --release`.

## Security

- All dependencies fetched over HTTPS from pub.dev or GitHub.
- No dependencies with known CVEs at time of writing.
- No proprietary or self-hosted packages.
