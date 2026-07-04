import 'dart:math' as math;

import 'dart:ui' as ui;

import 'package:app_flutter/domain/cesium_3d/projected_point.dart';
import 'package:app_flutter/domain/cesium_3d/tile_fetcher.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';

/// A tile coordinate in the Web Mercator tiling scheme.
///
/// [zoom] is the zoom level (0–12), [x] is the column, and [y] is the row
/// (0 at the top / north).
class TileCoord {
  /// The zoom level for this tile coordinate.
  final int zoom;

  /// The column index (0 = 180&deg; W, increases eastward).
  final int x;

  /// The row index (0 = 85.05&deg; N, increases southward).
  final int y;

  /// Creates a tile coordinate with the given [zoom], [x], and [y].
  const TileCoord({required this.zoom, required this.x, required this.y});

  /// A string key suitable for use in maps and sets.
  String get key => '$zoom/$x/$y';
}

/// Renders raster map-imagery tiles onto a 3-D globe canvas.
///
/// Tiles are fetched asynchronously via [TileFetcher] and decoded to
/// [ui.Image] instances. Only tiles whose corners project to the front
/// hemisphere are drawn. The active imagery [ImageryProvider] can be
/// changed at any time, which clears the local image cache and triggers
/// fresh fetches.
class GlobeTileRenderer {
  final TileFetcher _fetcher;
  ImageryProvider _activeProvider;
  final ui.VoidCallback? onTileLoaded;

  /// Decoded tile images keyed by "[zoom]/[x]/[y]". Limited to 64 entries.
  final Map<String, ui.Image> _loadedImages = {};

  /// Set of tile keys for which an HTTP fetch is currently in-flight.
  final Set<String> _pendingFetches = {};

  /// Creates a renderer that will fetch tiles via [fetcher] and initially
  /// use [initialProvider] as the imagery source.
  GlobeTileRenderer({
    required TileFetcher fetcher,
    ImageryProvider initialProvider = ImageryProvider.cartoDark,
    this.onTileLoaded,
  })  : _fetcher = fetcher,
        _activeProvider = initialProvider;

  /// Whether the underlying [TileFetcher] is enabled.
  bool get isEnabled => _fetcher.isEnabled();

  /// Switches to [provider] and clears all locally cached images and
  /// pending fetches so that new imagery is loaded.
  void setProvider(ImageryProvider provider) {
    if (_activeProvider == provider) return;
    _activeProvider = provider;
    _loadedImages.clear();
    _pendingFetches.clear();
    _fetcher.clearCache();
  }

  /// Converts degrees to radians.
  double _rad(double deg) => deg * math.pi / 180.0;

  // ---------------------------------------------------------------------------
  // Zoom computation
  // ---------------------------------------------------------------------------

  /// Derives a zoom level from the camera [altitude] (meters) and the
  /// [viewportWidth] (logical pixels).
  ///
  /// Clamped to the range 0–12. Small altitudes (close to the sphere)
  /// produce higher zoom values; high altitudes produce lower values.
  int _zoomForAltitude(double altitude, double viewportWidth) {
    double alt = altitude;
    if (alt <= 0) alt = 100;
    final zoom =
        (math.log(40075000.0 / (alt * 0.5)) / math.ln2).round();
    return zoom.clamp(0, 12);
  }

  // ---------------------------------------------------------------------------
  // Tile coordinate math (Web Mercator)
  // ---------------------------------------------------------------------------

  /// Converts latitude/longitude (degrees) to a tile coordinate at the
  /// given [zoom] level.
  TileCoord _latLngToTile(double lat, double lng, int zoom) {
    final n = math.pow(2, zoom).toInt();
    final x = ((lng + 180) / 360 * n).floor();
    final latRad = _rad(lat);
    final y =
        ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
                2 *
                n)
            .floor();
    return TileCoord(
        zoom: zoom, x: x.clamp(0, n - 1), y: y.clamp(0, n - 1));
  }

  /// Longitude of the *western* edge of tile column [x] at zoom [z].
  double _tile2lon(int x, int z) =>
      x / math.pow(2, z) * 360.0 - 180.0;

  /// Latitude of the *northern* edge of tile row [y] at zoom [z].
  double _tile2lat(int y, int z) {
    final n = math.pi * (1.0 - 2.0 * y / math.pow(2, z));
    return math.atan((math.exp(n) - math.exp(-n)) / 2.0) * 180.0 / math.pi;
  }

  // ---------------------------------------------------------------------------
  // Visible-tile computation
  // ---------------------------------------------------------------------------

  /// Returns the set of tile coordinates that cover the visible hemisphere
  /// from the current [camera] perspective.
  ///
  /// The centre tile is derived from the camera's lat/lng. A 4&times;4 grid
  /// (16 tiles) is then generated around it, clamped to valid Web Mercator
  /// bounds.
  List<TileCoord> _visibleTiles(VirtualCamera camera, ui.Size viewportSize) {
    final zoom = _zoomForAltitude(camera.altitude, viewportSize.width);
    final center = _latLngToTile(camera.latitude, camera.longitude, zoom);
    final n = math.pow(2, zoom).toInt();
    final List<TileCoord> tiles = [];

    for (int dx = -1; dx <= 2; dx++) {
      for (int dy = -1; dy <= 2; dy++) {
        final tx = (center.x + dx).clamp(0, n - 1);
        final ty = (center.y + dy).clamp(0, n - 1);
        tiles.add(TileCoord(zoom: zoom, x: tx, y: ty));
      }
    }
    return tiles;
  }

  // ---------------------------------------------------------------------------
  // Asynchronous tile fetching
  // ---------------------------------------------------------------------------

  /// Begins asynchronous fetching of all visible tiles for the given
  /// [camera] and [viewportSize].
  ///
  /// Tiles that are already loaded or whose fetch is already in-flight are
  /// skipped. Up to 16 concurrent fetches may be active at once.
  ///
  /// This method is safe to call on every frame — its work is bounded and
  /// it never blocks the UI thread.
  void beginTileFetch(VirtualCamera camera, ui.Size viewportSize) {
    if (!_fetcher.isEnabled()) return;
    _fetchVisibleTiles(camera, viewportSize); // fire-and-forget
  }

  Future<void> _fetchVisibleTiles(
      VirtualCamera camera, ui.Size viewportSize) async {
    final tiles = _visibleTiles(camera, viewportSize);

    final List<TileCoord> toFetch = [];
    for (final tile in tiles) {
      if (!_loadedImages.containsKey(tile.key) &&
          !_pendingFetches.contains(tile.key)) {
        toFetch.add(tile);
      }
    }

    // Cap at 16 concurrent in-flight requests.
    for (int i = 0; i < toFetch.length; i += 16) {
      final batch = toFetch.skip(i).take(16);
      await Future.wait(batch.map(_fetchAndDecode));
    }
  }

  Future<void> _fetchAndDecode(TileCoord tile) async {
    _pendingFetches.add(tile.key);
    try {
      final data = await _fetcher.fetchTile(
          _activeProvider, tile.zoom, tile.x, tile.y);
      if (data != null) {
        final codec = await ui.instantiateImageCodec(data);
        final frame = await codec.getNextFrame();
        final image = frame.image;
        _loadedImages[tile.key] = image;
        if (_loadedImages.length > 64) {
          _loadedImages.remove(_loadedImages.keys.first);
        }
        onTileLoaded?.call();
      }
    } finally {
      _pendingFetches.remove(tile.key);
    }
  }

  // ---------------------------------------------------------------------------
  // Synchronous tile rendering
  // ---------------------------------------------------------------------------

  /// Draws every loaded tile onto [canvas] using [projectFn] to map
  /// geographic coordinates to screen-space offsets.
  ///
  /// Only tiles whose four corners all lie at least partially on the front
  /// hemisphere (z &ge; 0) are drawn. Each tile is sourced from a 256&times;256
  /// pixel image and projected through [projectFn] into a screen-space
  /// destination rectangle derived from its geographic bounds.
  void renderTiles(
    ui.Canvas canvas,
    VirtualCamera camera,
    ui.Size size,
    ui.Offset center,
    double sphereRadius,
    ProjectedPoint Function(double lat, double lng) projectFn,
  ) {
    if (!_fetcher.isEnabled()) return;

    // Kick off fetches for tiles that may be needed soon.
    beginTileFetch(camera, size);

    for (final entry in _loadedImages.entries) {
      final key = entry.key;
      final parts = key.split('/');
      if (parts.length != 3) continue;
      final z = int.tryParse(parts[0]) ?? -1;
      final x = int.tryParse(parts[1]) ?? -1;
      final y = int.tryParse(parts[2]) ?? -1;
      if (z < 0 || x < 0 || y < 0) continue;

      // Geographic bounds for this tile.
      final double latN = _tile2lat(y, z);
      final double latS = _tile2lat(y + 1, z);
      final double lonW = _tile2lon(x, z);
      final double lonE = _tile2lon(x + 1, z);

      // Project the four corners to screen space.
      final nw = projectFn(latN, lonW);
      final ne = projectFn(latN, lonE);
      final se = projectFn(latS, lonE);
      final sw = projectFn(latS, lonW);

      // Cull tiles entirely on the back hemisphere.
      if (nw.z < 0 && ne.z < 0 && se.z < 0 && sw.z < 0) continue;

      // Compute an axis-aligned bounding box for the destination rect.
      final left = _min4(nw.offset.dx, ne.offset.dx, se.offset.dx, sw.offset.dx);
      final top = _min4(nw.offset.dy, ne.offset.dy, se.offset.dy, sw.offset.dy);
      final right = _max4(nw.offset.dx, ne.offset.dx, se.offset.dx, sw.offset.dx);
      final bottom = _max4(nw.offset.dy, ne.offset.dy, se.offset.dy, sw.offset.dy);

      final destRect = ui.Rect.fromLTRB(left, top, right, bottom);
      const srcRect = ui.Rect.fromLTWH(0, 0, 256, 256);

      canvas.drawImageRect(entry.value, srcRect, destRect, ui.Paint());
    }
  }

  double _min4(double a, double b, double c, double d) {
    double m = a;
    if (b < m) m = b;
    if (c < m) m = c;
    if (d < m) m = d;
    return m;
  }

  double _max4(double a, double b, double c, double d) {
    double m = a;
    if (b > m) m = b;
    if (c > m) m = c;
    if (d > m) m = d;
    return m;
  }
}
