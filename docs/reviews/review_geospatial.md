# 3D Geospatial & Camera Control Code Review

This document contains a thorough code review of the 3D Geospatial and FFI Camera Control components in the `app_flutter` codebase.

---

## Reviewed Files
1. [camera_controller.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/camera_controller.dart)
2. [globe_tile_renderer.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart)
3. [native_resource.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/native/native_resource.dart)
4. [bridge_bindings.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/native/bridge_bindings.dart)
5. [error_handler.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/native/error_handler.dart)
6. [tile_fetcher.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/tile_fetcher.dart)
7. [cesium_3d_native.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/cesium_3d_native.dart)
8. [cesium_engine.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/cesium_engine.dart)
9. [projected_point.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/projected_point.dart)
10. [coordinate_transformer.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/coordinate_transformer.dart)
11. [virtual_camera.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/virtual_camera.dart)
12. [camera_controller_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/test/cesium_3d/camera_controller_test.dart)
13. [globe_focus_test.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/test/cesium_3d/globe_focus_test.dart)

---

## 1. Context Understanding

These components form the core engine for a 3D Geospatial viewer, combining high-performance raster tile rendering (Web Mercator) with a virtual camera controller. The application bridges low-level calculations (WGS84 ECEF coordinates via FFI using `cesium-native` C++ bindings) with a Flutter-based 2D canvas drawing system (painting projection vertices). The core requirements are rendering correctness, low-latency rendering cycles, memory-safe FFI boundaries, and robust user interaction (panning, tilting, keyboard navigation).

---

## 2. Correctness Analysis

### 🔴 Infinite Loop on Non-Finite Coordinates in Angle Wrapping
- **Severity**: 🔴 Critical
- **Location**: [camera_controller.dart:93-104](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/camera_controller.dart#L93-L104) and [camera_controller.dart:198-212](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/camera_controller.dart#L198-L212)
- **Issue**: The angle wrapping functions `_wrapLng`, `_wrapHeadingStatic`, and `_wrapPitchStatic` use `while` loops to decrement or increment values:
  ```dart
  while (lng > 180) lng -= 360;
  while (lng < -180) lng += 360;
  ```
  If any input value propagates as `double.infinity` (which can happen during division-by-zero or mathematical edge cases in projection), the comparison `lng > 180` always remains true. This creates an infinite loop that freezes the main thread, resulting in an unresponsive application hang.
- **Suggestion**: Use the modulo operator to perform angle wrapping and explicitly check for `NaN` and `Infinite` double inputs.
- **Example**:
  ```dart
  static double _wrapLngStatic(double lng) {
    if (lng.isNaN || lng.isInfinite) return 0.0;
    double w = (lng + 180.0) % 360.0;
    if (w < 0.0) w += 360.0;
    return w - 180.0;
  }
  ```

---

### 🔴 NaN Check Bypass in `VirtualCamera` Constructor
- **Severity**: 🔴 Critical
- **Location**: [virtual_camera.dart:25-35](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/virtual_camera.dart#L25-L35)
- **Issue**: The `VirtualCamera` constructor performs range validations on coordinate properties:
  ```dart
  if (latitude < -90.0 || latitude > 90.0) { ... }
  ```
  However, in Dart, comparisons with `NaN` always return `false`. A camera instantiated with `latitude: double.nan` bypasses this validation entirely. These values propagate to rendering functions where operations like `.floor()` on `NaN` values throw an `UnsupportedError`, crashing the entire widget tree during paint cycles.
- **Suggestion**: Explicitly check for `isNaN` or `isInfinite` for all coordinate variables.
- **Example**:
  ```dart
  VirtualCamera({ ... }) {
    if (latitude.isNaN || longitude.isNaN || altitude.isNaN ||
        heading.isNaN || pitch.isNaN || roll.isNaN) {
      throw CoordinateValidationException('Coordinates cannot be NaN or Infinite.');
    }
    if (latitude < -90.0 || latitude > 90.0) { ... }
  }
  ```

---

### 🟠 Physically Incorrect Panning Scale Factor at Low Altitude
- **Severity**: 🟠 Important
- **Location**: [camera_controller.dart:107](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/camera_controller.dart#L107)
- **Issue**: The panning scale calculation:
  ```dart
  final double factor = (_camera.altitude + 500000.0) * 2.8074e-5 / shortestSide;
  ```
  adds a huge offset of `500000.0` meters. At low altitudes (e.g. 100 meters), the minimum speed factor levels off at about `0.0175` degrees per pixel. Panning a mere 100 pixels moves the camera by `1.75` degrees, jumping over 194 kilometers across the Earth's surface. This makes the camera extremely sensitive and completely unusable when zoomed in.
- **Suggestion**: Remove the massive constant offset or use a logarithmic/exponential curve that scales down to near zero at ground level.
- **Example**:
  ```dart
  final double factor = _camera.altitude * 2.8074e-5 / shortestSide;
  ```

---

### 🟠 Horizon Culling Failure at Negative Altitudes
- **Severity**: 🟠 Important
- **Location**: [scene_3d_viewport.dart:1095-1097](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart#L1095-L1097)
- **Issue**: The horizon culling checks the squared distance against a tangent limit:
  ```dart
  final double horizonLimitSq = cRad * cRad - R * R;
  final double depthVal = distSq > horizonLimitSq ? -1.0 : depth;
  ```
  If the altitude is negative (which is valid down to -100 meters), `cRad < R`, meaning `horizonLimitSq` becomes negative. As a result, `distSq > horizonLimitSq` is always true, causing all vertices to be culled and the entire globe to disappear.
- **Suggestion**: Use a mathematically robust vector dot product check to determine if the vertex is on the front hemisphere relative to the camera vector. This avoids negative altitude bugs, has no expensive square roots, and is computationally faster.
- **Example**:
  ```dart
  final double dot = px * cx + py * cy + pz * cz;
  final double depthVal = dot < R * R ? -1.0 : depth;
  ```

---

### 🟠 Concurrent Fetch Provider Race Condition
- **Severity**: 🟠 Important
- **Location**: [globe_tile_renderer.dart:208-226](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart#L208-L226)
- **Issue**: In `_fetchAndDecode`, when a tile is requested asynchronously, the active map provider might be changed via `setProvider` before the HTTP response or the image decoding completes. When the future resumes, it inserts the old provider's tile into `_loadedImages`, resulting in styled-layer mixing on screen and native memory leaks.
- **Suggestion**: Track the active provider at the start of the call and check it before saving or decoding the image. If the provider changed, discard the image and call `dispose()`.
- **Example**:
  ```dart
  Future<void> _fetchAndDecode(TileCoord tile) async {
    final providerAtStart = _activeProvider;
    _pendingFetches.add(tile.key);
    try {
      final data = await _fetcher.fetchTile(_activeProvider, tile.zoom, tile.x, tile.y);
      if (data != null) {
        if (_activeProvider != providerAtStart) return;
        final codec = await ui.instantiateImageCodec(data);
        final frame = await codec.getNextFrame();
        final image = frame.image;
        if (_activeProvider != providerAtStart) {
          image.dispose();
          return;
        }
        _loadedImages[tile.key] = image;
        // ...
      }
    } finally {
      _pendingFetches.remove(tile.key);
    }
  }
  ```

---

### 🟡 Missing Longitudinal Panning Cosine Latitude Scaling
- **Severity**: 🟡 Suggestion
- **Location**: [camera_controller.dart:118](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/camera_controller.dart#L118)
- **Issue**: When panning horizontally, the longitude shift does not account for the cosine of latitude:
  ```dart
  final newLng = _wrapLng(_camera.longitude - dxAligned * factor);
  ```
  Since the physical distance per degree of longitude shrinks towards the poles ($\text{distance} \propto \cos(\text{latitude})$), panning near high latitudes (e.g. poles) will feel distorted and warp much faster than near the Equator.
- **Suggestion**: Scale the longitudinal factor division by $\cos(\text{latitude})$, clamped to a safe minimum to avoid division by zero.
- **Example**:
  ```dart
  final double cosLat = math.cos(newLat * math.pi / 180.0).clamp(0.01, 1.0);
  final newLng = _wrapLng(_camera.longitude - dxAligned * factor / cosLat);
  ```

---

### 💡 Pitch and Roll Angular Wrapping Anomalies
- **Severity**: 💡 Nitpick
- **Location**: [camera_controller.dart:89](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/camera_controller.dart#L89)
- **Issue**: In `_lerpCamera`, the `roll` property is interpolated linearly `a.roll + (b.roll - a.roll) * t` without angle wrapping. A transition from `-170.0` to `170.0` will spin 340 degrees the long way around rather than crossing the boundary. Meanwhile, pitch uses `_wrapPitchStatic` which wraps around 180 degrees, but pitch is typically clamped to `[-90, 90]` in GIS configurations to prevent camera inversion.
- **Suggestion**: Implement proper shortest-path angular interpolation for `roll` (similar to heading), and clamp `pitch` to `[-90.0, 90.0]` or standard flight envelopes if camera inversions are forbidden.

---

## 3. Security Review

### 🔴 Native Double-Free Vulnerability in `NativeResource`
- **Severity**: 🔴 Critical
- **Location**: [native_resource.dart:19-22](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/native/native_resource.dart#L19-L22)
- **Issue**: The `NativeResource.release()` method manually frees native pointers via `calloc.free(pointer)`. However, there are no checks to prevent multiple invocations. Calling `release()` twice causes a **double-free** condition, corrupting the native allocator heap, crashing the application, and exposing potential arbitrary memory writes.
- **Suggestion**: Implement a `_isReleased` guard flag.
- **Example**:
  ```dart
  bool _isReleased = false;

  void release() {
    if (_isReleased) return;
    _isReleased = true;
    _finalizer.detach(this);
    calloc.free(pointer);
  }
  ```

---

### 🟠 Native Memory Leak in `CesiumEngine`
- **Severity**: 🟠 Important
- **Location**: [cesium_engine.dart:67-90](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/cesium_engine.dart#L67-L90)
- **Issue**: When calling native FFI methods like `getVisibleTileCount()` or `getVisibleTileId()`, memory pointers are allocated via `calloc<Int32>()` and `calloc<Pointer<Utf8>>()`. If `checkStatus(result)` throws an exception (e.g. tile retrieval fails with a negative status), the execution skips the manual `.free()` statements, resulting in a silent heap leak.
- **Suggestion**: Always wrap manual allocation code inside a `try-finally` block.
- **Example**:
  ```dart
  int getVisibleTileCount() {
    final countPtr = calloc<Int32>();
    try {
      final result = _bindings.getVisibleTileCount(_handle, countPtr);
      checkStatus(result);
      return countPtr.value;
    } finally {
      calloc.free(countPtr);
    }
  }
  ```

---

### 🟠 Socket/Connection Leaks on Error Responses in `TileFetcher`
- **Severity**: 🟠 Important
- **Location**: [tile_fetcher.dart:150-159](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/tile_fetcher.dart#L150-L159)
- **Issue**: In `fetchTile`, if `response.statusCode` is not 200 (e.g., 404, 500, or authorization failures), the method returns `null` immediately. In Dart, if an HTTP response stream is not fully read, drained, or closed, the underlying TCP socket remains active. This leaks sockets in the `HttpClient` pool, eventually causing socket exhaustion.
- **Suggestion**: Call `response.drain()` in the `else` block to close the socket correctly.
- **Example**:
  ```dart
  final response = await request.close();
  if (response.statusCode == 200) {
    // ...
  } else {
    await response.drain();
  }
  ```

---

### 🟠 Missing String Deallocation inside Exception Paths in `CesiumEngine`
- **Severity**: 🟠 Important
- **Location**: [cesium_engine.dart:85-88](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/cesium_engine.dart#L85-L88)
- **Issue**: In `getVisibleTileId`, the C++ bridge returns a string pointer that must be freed using `_bindings.freeString(idPtr.value)`. If calling `toDartString()` fails or throws an exception (e.g. due to invalid UTF-8 sequences), `freeString` is skipped, leaking the native string memory.
- **Suggestion**: Perform string copying and freeing in a nested `try-finally` block.
- **Example**:
  ```dart
  final rawStr = idPtr.value;
  if (rawStr != nullptr) {
    try {
      id = rawStr.toDartString();
    } finally {
      _bindings.freeString(rawStr);
    }
  }
  ```

---

## 4. Performance Considerations

### 🔴 GPU/Native Memory Leak: Missing `ui.Image` Disposal
- **Severity**: 🔴 Critical
- **Location**: [globe_tile_renderer.dart:66](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart#L66) and [globe_tile_renderer.dart:219](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart#L219)
- **Issue**: Flutter's `ui.Image` class is a thin wrapper around a native C++ object containing GPU texture backing store. The GC does not track this memory correctly unless explicitly disposed. In `setProvider()`, `_loadedImages.clear()` is called, and in `_fetchAndDecode()`, `_loadedImages.remove(...)` is called. In both cases, the image is discarded without calling `image.dispose()`. This creates a severe GPU memory leak, causing quick RAM/VRAM exhaustion and OOM crashes.
- **Suggestion**: Always call `.dispose()` on `ui.Image` instances when evicting or clearing the map.
- **Example**:
  ```dart
  if (_loadedImages.length > 64) {
    final firstKey = _loadedImages.keys.first;
    final evicted = _loadedImages.remove(firstKey);
    evicted?.dispose();
  }
  ```

---

### 🔴 High-Allocation FFI Double Pointers in Vertex Loop
- **Severity**: 🔴 Critical
- **Location**: [cesium_engine.dart:103-122](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/cesium_engine.dart#L103-L122) and [scene_3d_viewport.dart:1032](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart#L1032)
- **Issue**: In `Scene3DViewportPainter.project()`, `engine.cartographicToEcef` is called for every single subdivision vertex (25 vertices per tile, up to 64 tiles, making 1,600 calls per frame). Each invocation allocates three individual double pointers (`x`, `y`, `z`) using `calloc<Double>()` and immediately frees them. This adds up to **4,800 heap allocations and deallocations per frame** on the main thread, resulting in severe CPU overhead, GC churn, and rendering jank.
- **Suggestion**: Refactor the FFI interface to accept a single pointer pointing to an array of 3 doubles (e.g. `calloc<Double>(3)`), allocate this array buffer once per frame, or pass the values directly in a Struct.

---

### 🔴 Key Splitting and String Parsing in Paint Loops
- **Severity**: 🔴 Critical
- **Location**: [globe_tile_renderer.dart:252-257](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart#L252-L257)
- **Issue**: Inside `renderTiles()`, which runs on every single screen paint tick, the loaded tile entries are sorted by zoom level:
  ```dart
  final sortedEntries = _loadedImages.entries.toList()
    ..sort((e1, e2) {
      final z1 = int.tryParse(e1.key.split('/')[0]) ?? 0;
      final z2 = int.tryParse(e2.key.split('/')[0]) ?? 0;
      return z1.compareTo(z2);
    });
  ```
  This creates a list copy, runs `split` multiple times, and parses strings into integers inside a sort comparator on every frame. This triggers massive memory allocations, raising GC activity and lowering frame rates.
- **Suggestion**: Create a lightweight metadata wrapper `LoadedTile` containing the pre-parsed `TileCoord` and the `ui.Image`, then use it as the value in `_loadedImages`.
- **Example**:
  ```dart
  class LoadedTile {
    final TileCoord coord;
    final ui.Image image;
    LoadedTile(this.coord, this.image);
  }

  // Sort by integer directly:
  final sortedTiles = _loadedImages.values.toList()
    ..sort((a, b) => a.coord.zoom.compareTo(b.coord.zoom));
  ```

---

### 🟠 Redundant Matrix Allocations inside Painting Loops
- **Severity**: 🟠 Important
- **Location**: [globe_tile_renderer.dart:335-340](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart#L335-L340)
- **Issue**: For every tile rendered during paint, the image shader allocates a new `Float64List` representing the identity matrix:
  ```dart
  Float64List.fromList([
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0,
  ])
  ```
  This allocates a fresh native array buffer 64 times per frame.
- **Suggestion**: Store the identity matrix as a `static final` static constant.
- **Example**:
  ```dart
  static final Float64List _identityMatrix = Float64List.fromList([
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0,
  ]);
  ```

---

### 🟡 Duplicate Tile Coordinates in Visited Set
- **Severity**: 🟡 Suggestion
- **Location**: [globe_tile_renderer.dart:194-200](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart#L194-L200)
- **Issue**: Due to spatial coordinate clamping (e.g. boundary checks on screen edges), `_visibleTiles` can generate duplicate tile coordinates in the returned list. Because `_pendingFetches` is only populated when a fetch starts, the check `!_pendingFetches.contains(tile.key)` does not block duplicates within the same batch. This causes redundant HTTP requests and image decoding for the same boundary tiles.
- **Suggestion**: Filter out duplicate tile keys in `_fetchVisibleTiles` using a set.
- **Example**:
  ```dart
  final Set<String> seenKeys = {};
  for (final tile in tiles) {
    if (!seenKeys.add(tile.key)) continue;
    if (!_loadedImages.containsKey(tile.key) && !_pendingFetches.contains(tile.key)) {
      toFetch.add(tile);
    }
  }
  ```

---

## 5. Code Quality & Readability

### 💡 Unused Methods and Fields
- **Severity**: 💡 Nitpick
- **Location**: [globe_tile_renderer.dart:347-361](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart#L347-L361) and [cesium_3d_native.dart:8-9](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/cesium_3d_native.dart#L8-L9)
- **Issue**: The helper methods `_min4` and `_max4` in `globe_tile_renderer.dart` are defined but completely unused. In `cesium_3d_native.dart`, the private properties `_finalizerKey` and `_refcountKeys` are declared but never accessed.
- **Suggestion**: Remove these dead code elements to keep the codebase clean.

---

### 💡 Dead Native Bridge Reference Stubs
- **Severity**: 💡 Nitpick
- **Location**: [cesium_3d_native.dart:7-45](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/cesium_3d_native.dart#L7-L45) and [native_resource.dart:6-23](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/native/native_resource.dart#L6-L23)
- **Issue**: `Cesium3DNative` is a mock/stub class that is never utilized inside `app_flutter/lib`. Similarly, the `NativeResource` FFI class is fully defined but has zero active references in the app or tests.
- **Suggestion**: Clean up or complete the integration of these classes to avoid developer confusion.

---

## 6. Architecture & Design

### 🟠 Commingling Calculations and Rendering Loops
- **Severity**: 🟠 Important
- **Location**: [globe_tile_renderer.dart:239-345](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart#L239-L345)
- **Issue**: `renderTiles` performs geometry calculations, texture coordinate mapping, projection functions (`projectFn`), culling checks, and index array construction sequentially inside the paint loop. Mixing calculations with Canvas rendering logic violates the Single Responsibility Principle and blocks layout caching.
- **Suggestion**: Separate the generation of mesh geometry (vertices, texture coords, indices) from the actual drawing commands. Generate/cache the mesh updates in a separate controller phase, and let the painting class only invoke `canvas.drawVertices` on pre-computed models.

---

### 🟡 hardcoded Viewport Projection Logic
- **Severity**: 🟡 Suggestion
- **Location**: [scene_3d_viewport.dart:357-430](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart#L357-L430) and [scene_3d_viewport.dart:1021-1107](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/topology/scene_3d_viewport.dart#L1021-L1107)
- **Issue**: The projection matrix operations, WGS84 ellipsoid math, and inverse viewport transformations (transforming screen click points back to GPS coordinates in `_clickToCamera`) are hardcoded directly into the Flutter UI widget/painter files rather than being isolated in a dedicated domain-level math/coordinate class.
- **Suggestion**: Move WGS84 projection and raycast-to-coordinate calculations into `CoordinateTransformer` or a similar domain service, keeping UI files strictly focused on widgets and rendering.

---

## 7. Testing

### 🟡 Brittle Test State Access
- **Severity**: 🟡 Suggestion
- **Location**: [globe_focus_test.dart:37-39](file:///Users/perkunas/jail/3dgs-002/app_flutter/test/cesium_3d/globe_focus_test.dart#L37-L39)
- **Issue**: In `globe_focus_test.dart`, the test checks focus behavior by casting the viewport State to `dynamic` and reading private properties:
  ```dart
  final state = tester.state(find.byType(Scene3DViewport)) as dynamic;
  final CameraController controller = state.cameraController as CameraController;
  ```
  Even though these fields are decorated with `@visibleForTesting`, casting states to `dynamic` disables compiler checks, making tests brittle and prone to silent failures if names change.
- **Suggestion**: Expose necessary controllers or states through public testing interface wrappers, or use integration drivers rather than accessing state internals via reflection.

---

## 8. Documentation

### 💡 Undocumented Native Thread Restrictions
- **Severity**: 💡 Nitpick
- **Location**: [bridge_bindings.dart:153-203](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/cesium_3d/native/bridge_bindings.dart#L153-203)
- **Issue**: The FFI bindings invoke native C++ code directly on Flutter's main UI runner isolate thread. There is no documentation warning developers that heavy operations (like massive coordinate conversions or blocking file IO inside `bridge_initialize`) will freeze the UI thread.
- **Suggestion**: Add comments indicating that FFI initialization must run asynchronously or be moved to a background isolate (using Dart 3+ ports / isolates) if operations exceed 16ms frames.
