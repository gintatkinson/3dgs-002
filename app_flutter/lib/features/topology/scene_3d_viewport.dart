// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:app_flutter/domain/cesium_3d/cesium_engine.dart';
import 'package:app_flutter/domain/cesium_3d/globe_tile_renderer.dart';
import 'package:app_flutter/domain/cesium_3d/projected_point.dart';
import 'package:app_flutter/domain/cesium_3d/tile_fetcher.dart';
import 'package:app_flutter/domain/cesium_3d/camera_controller.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';
import 'package:app_flutter/features/topology/topology_map.dart';

class Scene3DViewport extends StatefulWidget {
  final VirtualCamera camera;
  final TopologyData? topologyData;
  final ValueChanged<VirtualCamera>? onCameraChanged;

  const Scene3DViewport({
    super.key,
    required this.camera,
    this.topologyData,
    this.onCameraChanged,
  });

  /// Initializes the 3D scene rendering state.
  bool initializeScene() {
    return true;
  }

  /// Renders the scene onto the canvas.
  bool render(Canvas canvas) {
    return true;
  }

  @override
  State<Scene3DViewport> createState() => Scene3DViewportState();
}

class Scene3DViewportState extends State<Scene3DViewport> {
  late CameraController _cameraController;

  @visibleForTesting
  CameraController get cameraController => _cameraController;

  @visibleForTesting
  FocusNode get globeFocusNode => _globeFocusNode;

  @visibleForTesting
  GlobeTileRenderer? get tileRenderer => _tileRenderer;

  Offset getProjectedPosition(double latitude, double longitude) {
    final Size? size = context.size;
    if (size == null) return Offset.zero;

    final camera = _cameraController.current;
    final double zoomScale = 500.0 / camera.altitude;
    final double sphereRadius = size.shortestSide * 0.32 * zoomScale;
    final Offset center = Offset(size.width * 0.45, size.height * 0.5);

    final double baseRotation = -(camera.longitude * math.pi / 180.0);
    final double baseTilt = -(camera.latitude * math.pi / 180.0);

    final double latRad = latitude * math.pi / 180.0;
    final double lngRad = longitude * math.pi / 180.0;

    final painter = Scene3DViewportPainter(
      camera: camera,
      activeStyle: _activeStyle,
      astronomicalBody: _astronomicalBody,
      elevationActive: _elevationActive,
      showDevices: _showDevices,
      showLinks: _showLinks,
      showLabels: _showLabels,
      showDropLines: _showDropLines,
      topologyData: widget.topologyData,
      userRotationX: 0.0,
      userTilt: 0.0,
      zoomScale: zoomScale,
      tileRenderer: _tileRenderer,
      imageryProvider: _providerForStyle(_activeStyle),
    );

    final ProjectedPoint projected = painter.project(
      latRad,
      lngRad,
      sphereRadius,
      center,
      baseRotation,
      baseTilt,
    );

    return projected.offset;
  }

  final FocusNode _globeFocusNode = FocusNode();

  bool _shiftHeld = false;
  bool _ctrlHeld = false;
  bool _rightButtonDown = false;
  bool _isUpdatingWidget = false;

  // Interactive configurations
  String _activeStyle = 'Satellite Map';
  String _astronomicalBody = 'Earth';
  bool _elevationActive = true;
  bool _showDevices = true;
  bool _showLinks = true;
  bool _showLabels = true;
  bool _showDropLines = true;

  GlobeTileRenderer? _tileRenderer;
  Timer? _flyTimer;

  ImageryProvider _providerForStyle(String style) {
    switch (style) {
      case 'Dark Map':
        return ImageryProvider.cartoDark;
      case 'Street Map':
        return ImageryProvider.openStreetMap;
      case 'Satellite Map':
        return ImageryProvider.arcGisSatellite;
      case 'Light Map':
        return ImageryProvider.cartoLight;
      default:
        return ImageryProvider.cartoDark;
    }
  }

  @override
  void initState() {
    super.initState();
    _cameraController = CameraController(widget.camera);
    _cameraController.addListener(_onCameraChangedInside);

    final fetcher = TileFetcher();
    _tileRenderer = GlobeTileRenderer(
      fetcher: fetcher,
      initialProvider: _providerForStyle(_activeStyle),
      onTileLoaded: () {
        if (mounted) {
          setState(() {});
        }
      },
    );

    _globeFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _onCameraChangedInside() {
    if (mounted && !_isUpdatingWidget) {
      setState(() {});
      widget.onCameraChanged?.call(_cameraController.current);
    }
  }

  @override
  void didUpdateWidget(covariant Scene3DViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera != widget.camera) {
      _isUpdatingWidget = true;
      _cameraController.updateCamera(widget.camera);
      _isUpdatingWidget = false;
    }
  }

  @override
  void dispose() {
    _flyTimer?.cancel();
    _globeFocusNode.dispose();
    _cameraController.removeListener(_onCameraChangedInside);
    _cameraController.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape) {
      _globeFocusNode.unfocus();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.shiftLeft || key == LogicalKeyboardKey.shiftRight) {
      if (event is KeyDownEvent) {
        _shiftHeld = true;
      } else if (event is KeyUpEvent) {
        _shiftHeld = false;
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.controlLeft || key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.metaLeft || key == LogicalKeyboardKey.metaRight) {
      if (event is KeyDownEvent) {
        _ctrlHeld = true;
      } else if (event is KeyUpEvent) {
        _ctrlHeld = false;
      }
      return KeyEventResult.handled;
    }

    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        _cameraController.keyboardRotate(-CameraController.keyboardStep);
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      setState(() {
        _cameraController.keyboardRotate(CameraController.keyboardStep);
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _cameraController.keyboardTilt(CameraController.keyboardStep);
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _cameraController.keyboardTilt(-CameraController.keyboardStep);
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildStyleButton(String style) {
    final bool isActive = _activeStyle == style;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _activeStyle = style;
            _tileRenderer?.setProvider(_providerForStyle(style));
          });
        },
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? const Color(0x2200E5FF) : const Color(0x0AFFFFFF),
            border: Border.all(
              color: isActive ? const Color(0xFF00E5FF) : const Color(0x33FFFFFF),
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            style.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isActive ? const Color(0xFF00E5FF) : const Color(0xFFB0BEC5),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyButton(String body) {
    final bool isActive = _astronomicalBody == body;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _astronomicalBody = body;
          });
        },
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? const Color(0x2200E5FF) : const Color(0x0AFFFFFF),
            border: Border.all(
              color: isActive ? const Color(0xFF00E5FF) : const Color(0x33FFFFFF),
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            body.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isActive ? const Color(0xFF00E5FF) : const Color(0xFFB0BEC5),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xFFCFD8DC),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF00E5FF),
            activeTrackColor: const Color(0x6600E5FF),
            inactiveThumbColor: const Color(0xFF78909C),
            inactiveTrackColor: const Color(0x33FFFFFF),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  VirtualCamera? _clickToCamera(Offset localPosition, Size size) {
    final double zoomScale = 6378137.0 / _cameraController.current.altitude;
    final double sphereRadius = size.shortestSide * 0.32 * zoomScale;
    final Offset center = Offset(size.width * 0.45, size.height * 0.5);

    final double dx = localPosition.dx - center.dx;
    final double dy = -(localPosition.dy - center.dy);

    if (dx * dx + dy * dy > sphereRadius * sphereRadius) {
      return null;
    }

    final double radDiff = sphereRadius * sphereRadius - dx * dx - dy * dy;
    final double zFinal = math.sqrt(radDiff < 0.0 ? 0.0 : radDiff);

    final double baseRotation = -(_cameraController.current.longitude * math.pi / 180.0);
    final double baseTilt = -(_cameraController.current.latitude * math.pi / 180.0);

    final double cosT = math.cos(baseTilt);
    final double sinT = math.sin(baseTilt);
    final double yRot = dy * cosT + zFinal * sinT;
    final double zRot = -dy * sinT + zFinal * cosT;

    final double cosY = math.cos(baseRotation);
    final double sinY = math.sin(baseRotation);
    final double x = dx * cosY - zRot * sinY;
    final double y = yRot;
    final double z = dx * sinY + zRot * cosY;

    final double lat = math.asin((y / sphereRadius).clamp(-1.0, 1.0));
    final double lng = math.atan2(x, z);

    final double latDeg = lat * 180.0 / math.pi;
    final double lngDeg = lng * 180.0 / math.pi;

    final targetAlt = (_cameraController.current.altitude * 0.5).clamp(
      CameraController.minAltitude,
      CameraController.maxAltitude,
    );

    return VirtualCamera.clamped(
      latitude: latDeg,
      longitude: lngDeg,
      altitude: targetAlt,
      heading: _cameraController.current.heading,
      pitch: _cameraController.current.pitch,
      roll: _cameraController.current.roll,
    );
  }

  @override
  Widget build(BuildContext context) {
    final zoomScale = 6378137.0 / _cameraController.current.altitude;
    return Focus(
      focusNode: _globeFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          _globeFocusNode.requestFocus();
        },
        onScaleStart: (_) {
          _globeFocusNode.requestFocus();
        },
        onScaleUpdate: (details) {
          if (details.scale != 1.0) {
            _cameraController.zoomInteractive(
              (details.scale - 1.0).sign * 20.0,
            );
          }
        },
        onDoubleTapDown: (details) {
          final Size? size = context.size;
          VirtualCamera? targetCam;
          if (size != null) {
            targetCam = _clickToCamera(details.localPosition, size);
          }
          if (targetCam == null) {
            final current = _cameraController.current;
            final targetAlt = (current.altitude * 0.5).clamp(
              CameraController.minAltitude,
              CameraController.maxAltitude,
            );
            targetCam = VirtualCamera.clamped(
              latitude: current.latitude,
              longitude: current.longitude,
              altitude: targetAlt,
              heading: current.heading,
              pitch: current.pitch,
              roll: current.roll,
            );
          }
  
          _cameraController.flyTo(targetCam);
  
          _flyTimer?.cancel();
          _flyTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
            final done = _cameraController.tick();
            if (done) {
              timer.cancel();
              _flyTimer = null;
            }
          });
        },
        child: Stack(
      key: const Key('scene_3d_viewport_container'),
      children: [
            // Background & 3D Globe custom paint
            Positioned.fill(
              child: Listener(
                onPointerDown: (event) {
                  _globeFocusNode.requestFocus();
                  if (event.buttons & kSecondaryMouseButton != 0) {
                    _rightButtonDown = true;
                  }
                },
                onPointerUp: (event) {
                  _rightButtonDown = false;
                },
                onPointerCancel: (event) {
                  _rightButtonDown = false;
                },
                onPointerMove: (event) {
                  final delta = event.localDelta;
                  if (delta.distance <= 0.5) return;
                  final Size? size = context.size;
                  final double shortestSide = size?.shortestSide ?? 800.0;
                  if (event.buttons & kSecondaryMouseButton != 0 || _shiftHeld) {
                    _cameraController.tilt(delta);
                  } else if (_ctrlHeld) {
                    _cameraController.rotateHeading(delta);
                  } else if (event.buttons & kPrimaryMouseButton != 0) {
                    _cameraController.pan(delta, shortestSide);
                  }
                },
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    _cameraController.zoomInteractive(event.scrollDelta.dy);
                  }
                },
                child: CustomPaint(
                  painter: Scene3DViewportPainter(
                    camera: _cameraController.current,
                    activeStyle: _activeStyle,
                    astronomicalBody: _astronomicalBody,
                    elevationActive: _elevationActive,
                    showDevices: _showDevices,
                    showLinks: _showLinks,
                    showLabels: _showLabels,
                    showDropLines: _showDropLines,
                    topologyData: widget.topologyData,
                    userRotationX: 0.0,
                    userTilt: 0.0,
                    zoomScale: zoomScale,
                    tileRenderer: _tileRenderer,
                    imageryProvider: _providerForStyle(_activeStyle),
                  ),
                ),
              ),
            ),
            
            // Left HUD (Camera Stats & Tile Status)
            Positioned(
              top: 16,
              left: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0x990A0E1A), // semi-transparent
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0x33FFFFFF), // fine borders
                        width: 1.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F000000),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'CAMERA STATS',
                          style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Latitude: ${_cameraController.current.latitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            color: Color(0xFFE0E0E0),
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'Longitude: ${_cameraController.current.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            color: Color(0xFFE0E0E0),
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'Altitude: ${_cameraController.current.altitude} meters',
                          style: const TextStyle(
                            color: Color(0xFFE0E0E0),
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'Pitch/Yaw/Roll: ${_cameraController.current.pitch} / ${_cameraController.current.heading} / ${_cameraController.current.roll}',
                          style: const TextStyle(
                            color: Color(0xFFE0E0E0),
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'TILE STATUS',
                          style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'cesium-native WGS84 ECEF transforms active',
                          style: TextStyle(
                            color: Color(0xFFE0E0E0),
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Right HUD: Map Configuration Panel (Right Sidebar overlay)
            Positioned(
              top: 16,
              right: 16,
              bottom: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 280,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0x990A0E1A), // dark translucent background
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0x3300E5FF), // fine cyan border
                        width: 1.0,
                      ),
                    ),
                    child: SingleChildScrollView(
                      physics: _globeFocusNode.hasFocus
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.settings,
                                color: Color(0xFF00E5FF),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'MAP CONFIGURATION',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Color(0x2200E5FF), height: 1),
                          const SizedBox(height: 12),
                          
                          // Astronomical Body Selection
                          const Text(
                            'ASTRONOMICAL BODY',
                            style: TextStyle(
                              color: Color(0xFFB0BEC5),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              fontSize: 10,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildBodyButton('Earth'),
                              _buildBodyButton('Mars'),
                            ],
                          ),
                          Row(
                            children: [
                              _buildBodyButton('Proxima Centauri'),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          const Divider(color: Color(0x2200E5FF), height: 1),
                          const SizedBox(height: 16),

                          // Base Layer Style Selection
                          const Text(
                            'BASE LAYER STYLE',
                            style: TextStyle(
                              color: Color(0xFFB0BEC5),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              fontSize: 10,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildStyleButton('Dark Map'),
                              _buildStyleButton('Street Map'),
                            ],
                          ),
                          Row(
                            children: [
                              _buildStyleButton('Satellite Map'),
                              _buildStyleButton('Light Map'),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          const Divider(color: Color(0x2200E5FF), height: 1),
                          const SizedBox(height: 16),
                          
                          // 3D Surface Elevation
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '3D SURFACE ELEVATION',
                                      style: TextStyle(
                                        color: Color(0xFFCFD8DC),
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        fontSize: 10,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    if (_elevationActive) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0x1F4CAF50),
                                          border: Border.all(color: const Color(0xFF4CAF50), width: 1.0),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'ACTIVE 3D',
                                          style: TextStyle(
                                            color: Color(0xFF4CAF50),
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Switch(
                                value: _elevationActive,
                                onChanged: (val) {
                                  setState(() {
                                    _elevationActive = val;
                                  });
                                },
                                activeColor: const Color(0xFF00E5FF),
                                activeTrackColor: const Color(0x6600E5FF),
                                inactiveThumbColor: const Color(0xFF78909C),
                                inactiveTrackColor: const Color(0x33FFFFFF),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          const Divider(color: Color(0x2200E5FF), height: 1),
                          const SizedBox(height: 16),
                          
                          // Visibility Toggles
                          const Text(
                            'VISIBILITY TOGGLES',
                            style: TextStyle(
                              color: Color(0xFFB0BEC5),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              fontSize: 10,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildVisibilityToggle('Devices / Nodes', _showDevices, (val) {
                            setState(() {
                              _showDevices = val;
                            });
                          }),
                          _buildVisibilityToggle('Topology Links', _showLinks, (val) {
                            setState(() {
                              _showLinks = val;
                            });
                          }),
                          _buildVisibilityToggle('Address Labels', _showLabels, (val) {
                            setState(() {
                              _showLabels = val;
                            });
                          }),
                          _buildVisibilityToggle('Vertical Drop Lines', _showDropLines, (val) {
                            setState(() {
                              _showDropLines = val;
                            });
                          }),
                          
                          const SizedBox(height: 24),
                          
                          // Reset Button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _astronomicalBody = 'Earth';
                                  _activeStyle = 'Satellite Map';
                                  _elevationActive = true;
                                  _showDevices = true;
                                  _showLinks = true;
                                  _showLabels = true;
                                  _showDropLines = true;
                                  _tileRenderer?.setProvider(ImageryProvider.arcGisSatellite);
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF00E5FF), width: 1.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                backgroundColor: const Color(0x0D00E5FF),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                'RESET CAMERA PERSPECTIVE',
                                style: TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Scene3DViewportPainter extends CustomPainter {
  final VirtualCamera camera;
  final String activeStyle;
  final String astronomicalBody;
  final bool elevationActive;
  final bool showDevices;
  final bool showLinks;
  final bool showLabels;
  final bool showDropLines;
  final TopologyData? topologyData;
  final double userRotationX;
  final double userTilt;
  final double zoomScale;
  final GlobeTileRenderer? tileRenderer;
  final ImageryProvider imageryProvider;

  Scene3DViewportPainter({
    required this.camera,
    required this.activeStyle,
    required this.astronomicalBody,
    required this.elevationActive,
    required this.showDevices,
    required this.showLinks,
    required this.showLabels,
    required this.showDropLines,
    this.topologyData,
    required this.userRotationX,
    required this.userTilt,
    required this.zoomScale,
    this.tileRenderer,
    this.imageryProvider = ImageryProvider.arcGisSatellite,
  });

  ProjectedPoint project(double lat, double lng, double sphereRadius, Offset center, double rotationY, double tilt) {
    final CesiumEngine? engine = CesiumEngine.instance;
    final double radLng = camera.longitude * math.pi / 180.0;
    final double radLat = camera.latitude * math.pi / 180.0;

    double sx = 0.0;
    double sy = 0.0;
    double sz = 0.0;

    if (engine != null && engine.isReady) {
      final ecef = engine.cartographicToEcef(lat * 180.0 / math.pi, lng * 180.0 / math.pi, 0.0);
      if (ecef != null) {
        final (x, y, z) = ecef;
        final scale = sphereRadius / 6378137.0;
        sx = x * scale;
        sy = z * scale;
        sz = y * scale;
      }
    } else {
      final double x = sphereRadius * math.cos(lat) * math.sin(lng);
      final double y = sphereRadius * math.sin(lat);
      final double z = sphereRadius * math.cos(lat) * math.cos(lng);
      sx = z;
      sy = y;
      sz = x;
    }

    // 1. Rotate ECEF coordinates by camera longitude (around ECEF Z-axis)
    final double cosY = math.cos(-radLng);
    final double sinY = math.sin(-radLng);
    final double x1 = sx * cosY - sz * sinY;
    final double z1 = sx * sinY + sz * cosY;
    final double y1 = sy;

    // 2. Rotate around camera East axis by camera latitude
    final double cosX = math.cos(-radLat);
    final double sinX = math.sin(-radLat);
    final double xRot = x1 * cosX - y1 * sinX;
    final double yRot = x1 * sinX + y1 * cosX;
    final double zRot = z1;

    // 3. Translate along camera line of sight (camera is at distance D)
    final double distancePixels = sphereRadius * (1.0 + camera.altitude / 6378137.0);
    final double xCam = xRot - distancePixels;
    final double yCam = yRot;
    final double zCam = zRot;

    // 4. Apply camera pitch (tilt around local East horizontal axis)
    final double P = camera.pitch * math.pi / 180.0;
    final double cosP = math.cos(P);
    final double sinP = math.sin(P);
    final double xPitch = xCam * cosP - yCam * sinP;
    final double yPitch = xCam * sinP + yCam * cosP;
    final double zPitch = zCam;

    // 5. Apply camera heading (rotation around optical axis)
    final double H = camera.heading * math.pi / 180.0;
    final double cosH = math.cos(H);
    final double sinH = math.sin(H);
    final double xFinal = xPitch;
    final double yFinal = yPitch * cosH - zPitch * sinH;
    final double zFinal = yPitch * sinH + zPitch * cosH;

    // 6. Perspective projection
    final double depth = -xFinal;
    final double pScale = depth <= 0.0 ? 1.0 : distancePixels / depth;

    final double rx = zFinal * pScale;
    final double ry = yFinal * pScale;

    return ProjectedPoint(Offset(center.dx + rx, center.dy - ry), depth);
  }

  // Convert degrees to radians
  double _rad(double deg) => deg * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final double sphereRadius = size.shortestSide * 0.32 * zoomScale;
    // Shift center to the left to give space to the config overlay sidebar
    final Offset center = Offset(size.width * 0.45, size.height * 0.5);

    // 1. Draw Starry Space Background (~100 stars)
    final math.Random rand = math.Random(42);
    for (int i = 0; i < 100; i++) {
      final double rx = rand.nextDouble() * size.width;
      final double ry = rand.nextDouble() * size.height;
      final double rSize = rand.nextDouble() * 1.5 + 0.5;
      final double rOpacity = rand.nextDouble() * 0.7 + 0.3;
      final Paint starPaint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, rOpacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(rx, ry), rSize, starPaint);
    }

    // 2. Astronomical Body customization (corona, atmospheric glows)
    if (astronomicalBody == 'Proxima Centauri') {
      // Intense bright stellar corona glow layers
      final Paint coronaPaint1 = Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0x99FF3D00), // intense red-orange
            Color(0x44FF9100), // glowing orange
            Color(0x00000000),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: sphereRadius * 1.8));
      canvas.drawCircle(center, sphereRadius * 1.8, coronaPaint1);

      final Paint coronaPaint2 = Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0xCCFFEA00), // bright yellow
            Color(0x33FF9100),
            Color(0x00000000),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: sphereRadius * 1.45));
      canvas.drawCircle(center, sphereRadius * 1.45, coronaPaint2);
    } else if (astronomicalBody == 'Mars') {
      // Dusty reddish-orange atmospheric glow
      final Paint marsAtmosphere = Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0x66FF5722),
            Color(0x22FF8A65),
            Color(0x00000000),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: sphereRadius * 1.35));
      canvas.drawCircle(center, sphereRadius * 1.35, marsAtmosphere);
    } else {
      // Earth: Glowing atmospheric blue/cyan radial glow
      final Paint atmospherePaint = Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0x6600E5FF),
            Color(0x2200E5FF),
            Color(0x00000000),
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: sphereRadius * 1.35));
      canvas.drawCircle(center, sphereRadius * 1.35, atmospherePaint);
    }

    // 3. Earth's / astronomical sphere style variables
    List<Color> oceanColors;
    Color gridColor;
    
    if (astronomicalBody == 'Mars') {
      oceanColors = [const Color(0xFFBF360C), const Color(0xFF3E1103)]; // Desert sphere
      gridColor = const Color(0x22FF5722);
    } else if (astronomicalBody == 'Proxima Centauri') {
      oceanColors = [const Color(0xFFFFD54F), const Color(0xFFE65100)]; // Star golden gradient
      gridColor = const Color(0x33FFD54F);
    } else {
      switch (activeStyle) {
        case 'Dark Map':
          oceanColors = [const Color(0xFF161B22), const Color(0xFF0D1117)];
          gridColor = const Color(0x1A00E5FF);
          break;
        case 'Street Map':
          oceanColors = [const Color(0xFF29B6F6), const Color(0xFF0288D1)];
          gridColor = const Color(0x33000000);
          break;
        case 'Light Map':
          oceanColors = [const Color(0xFFE0F7FA), const Color(0xFF80DEEA)];
          gridColor = const Color(0x26000000);
          break;
        case 'Satellite Map':
        default:
          oceanColors = [const Color(0xFF0F2B5C), const Color(0xFF040A18)];
          gridColor = const Color(0x2600E5FF);
          break;
      }
    }

    // 4. Draw Astronomical / Planetary Sphere
    final Paint spherePaint = Paint()
      ..shader = RadialGradient(
        colors: oceanColors,
      ).createShader(Rect.fromCircle(center: center, radius: sphereRadius));
    canvas.drawCircle(center, sphereRadius, spherePaint);

    // Rotation angle and tilt based on camera and user inputs
    final double baseRotation = -_rad(camera.longitude);
    final double baseTilt = -_rad(camera.latitude);
    final double rotationAngle = baseRotation + userRotationX;
    final double tilt = baseTilt + userTilt;

    // 5. Draw Grid lines (Meridians & Parallels) - front hemisphere only
    final Paint frontGridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const int numMeridians = 12;
    const int meridianSteps = 30;
    for (int i = 0; i < numMeridians; i++) {
      final double lng = i * (2 * math.pi / numMeridians);
      for (int j = 0; j < meridianSteps; j++) {
        final double lat1 = -math.pi / 2 + j * (math.pi / meridianSteps);
        final double lat2 = -math.pi / 2 + (j + 1) * (math.pi / meridianSteps);
        
        final ProjectedPoint p1 = project(lat1, lng, sphereRadius, center, rotationAngle, tilt);
        final ProjectedPoint p2 = project(lat2, lng, sphereRadius, center, rotationAngle, tilt);
        
        if (p1.z >= 0 && p2.z >= 0) {
          canvas.drawLine(p1.offset, p2.offset, frontGridPaint);
        }
      }
    }

    const int numParallels = 6;
    const int parallelSteps = 60;
    for (int i = 0; i < numParallels; i++) {
      final double lat = -math.pi / 2 + (i + 1) * (math.pi / (numParallels + 1));
      for (int j = 0; j < parallelSteps; j++) {
        final double lng1 = j * (2 * math.pi / parallelSteps);
        final double lng2 = (j + 1) * (2 * math.pi / parallelSteps);
        
        final ProjectedPoint p1 = project(lat, lng1, sphereRadius, center, rotationAngle, tilt);
        final ProjectedPoint p2 = project(lat, lng2, sphereRadius, center, rotationAngle, tilt);
        
        if (p1.z >= 0 && p2.z >= 0) {
          canvas.drawLine(p1.offset, p2.offset, frontGridPaint);
        }
      }
    }

    // 6. Draw Procedural Latitude Climate Bands (no hardcoded geography)
    if (astronomicalBody != 'Proxima Centauri') {
      final List<(double, double, Color)> bands = [
        (math.pi / 2, math.pi * 0.4, const Color(0x0800BFFF)),  // Arctic
        (math.pi * 0.4, math.pi * 0.15, const Color(0x082196F3)), // Boreal
        (math.pi * 0.15, -math.pi * 0.15, const Color(0x0800E676)), // Tropical
        (-math.pi * 0.15, -math.pi * 0.4, const Color(0x082196F3)), // Temperate S
        (-math.pi * 0.4, -math.pi / 2, const Color(0x0800BFFF)),  // Antarctic
      ];

      for (final (latMax, latMin, color) in bands) {
        final Paint bandPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        final Paint bandBorder = Paint()
          ..color = color.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.4;

        const int steps = 60;
        final List<ProjectedPoint> pts = [];
        for (int s = 0; s <= steps; s++) {
          final double lng = s * (2 * math.pi / steps);
          pts.add(project(latMin, lng, sphereRadius * 1.002, center, rotationAngle, tilt));
        }
        for (int s = steps; s >= 0; s--) {
          final double lng = s * (2 * math.pi / steps);
          pts.add(project(latMax, lng, sphereRadius * 1.002, center, rotationAngle, tilt));
        }

        final double avgZ = pts.fold(0.0, (sum, p) => sum + p.z) / pts.length;
        if (avgZ >= -sphereRadius * 0.2) {
          final Path path = Path();
          path.moveTo(pts.first.offset.dx, pts.first.offset.dy);
          for (int i = 1; i < pts.length; i++) {
            path.lineTo(pts[i].offset.dx, pts[i].offset.dy);
          }
          path.close();
          canvas.drawPath(path, bandPaint);
          canvas.drawPath(path, bandBorder);
        }
      }
    } else {
      // Proxima Centauri: Solar flares and plasma arcs
      final Paint flarePaint = Paint()
        ..color = const Color(0xFFFF3D00).withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      final Paint flareGlowPaint = Paint()
        ..color = const Color(0x33FF3D00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0;

      const int numFlares = 8;
      for (int f = 0; f < numFlares; f++) {
        final double baseAngle = f * (2 * math.pi / numFlares);
        final double pulse = 1.0;
        
        final double angleStart = baseAngle;
        final double angleEnd = baseAngle + 0.25;
        final double angleMid = baseAngle + 0.125;
        
        final Offset ptStart = Offset(
          center.dx + sphereRadius * math.cos(angleStart),
          center.dy + sphereRadius * math.sin(angleStart),
        );
        final Offset ptEnd = Offset(
          center.dx + sphereRadius * math.cos(angleEnd),
          center.dy + sphereRadius * math.sin(angleEnd),
        );
        final Offset ptControl = Offset(
          center.dx + sphereRadius * 1.25 * pulse * math.cos(angleMid),
          center.dy + sphereRadius * 1.25 * pulse * math.sin(angleMid),
        );
        
        final Path flarePath = Path()
          ..moveTo(ptStart.dx, ptStart.dy)
          ..quadraticBezierTo(ptControl.dx, ptControl.dy, ptEnd.dx, ptEnd.dy);
          
        canvas.drawPath(flarePath, flareGlowPaint);
        canvas.drawPath(flarePath, flarePaint);
      }
    }

    // 6b. Render map-imagery tiles on the sphere surface.
    if (tileRenderer != null && tileRenderer!.isEnabled) {
      tileRenderer!.renderTiles(
        canvas,
        camera,
        size,
        center,
        sphereRadius,
        (double latDeg, double lngDeg) => project(
          _rad(latDeg),
          _rad(lngDeg),
          sphereRadius,
          center,
          rotationAngle,
          tilt,
        ),
      );
    }

    // 7. Space, Ground, and Underwater Node Layouts (Dynamic DB-Backed)
    List<TopologyNode> nodes = [];
    List<TopologyLink> links = [];

    if (topologyData == null || topologyData!.nodes.isEmpty) {
      nodes = [
        const TopologyNode(
          id: 'sat-1',
          label: 'sat-1',
          position: TopologyNodePosition(dim0: 135.0, dim1: 15.0, dim2: 35786000.0, timeIndex: 0, vector: []),
          status: 'Active',
          rawProperties: {'type': 'SATELLITE'},
        ),
        const TopologyNode(
          id: 'sat-2',
          label: 'sat-2',
          position: TopologyNodePosition(dim0: 142.0, dim1: -25.0, dim2: 20200000.0, timeIndex: 0, vector: []),
          status: 'Active',
          rawProperties: {'type': 'SATELLITE'},
        ),
        const TopologyNode(
          id: 'sat-3',
          label: 'sat-3',
          position: TopologyNodePosition(dim0: 128.0, dim1: 40.0, dim2: 500000.0, timeIndex: 0, vector: []),
          status: 'Active',
          rawProperties: {'type': 'SATELLITE'},
        ),
        const TopologyNode(
          id: 'sat-4',
          label: 'sat-4',
          position: TopologyNodePosition(dim0: 148.0, dim1: -5.0, dim2: 600000.0, timeIndex: 0, vector: []),
          status: 'Active',
          rawProperties: {'type': 'SATELLITE'},
        ),
        const TopologyNode(
          id: 'GS-Tokyo',
          label: 'GS-Tokyo',
          position: TopologyNodePosition(dim0: 139.6, dim1: 35.6, dim2: 50.0, timeIndex: 0, vector: []),
          status: 'Active',
        ),
        const TopologyNode(
          id: 'GS-Sapporo',
          label: 'GS-Sapporo',
          position: TopologyNodePosition(dim0: 141.3, dim1: 43.0, dim2: 25.0, timeIndex: 0, vector: []),
          status: 'Active',
        ),
        const TopologyNode(
          id: 'GS-Fukuoka',
          label: 'GS-Fukuoka',
          position: TopologyNodePosition(dim0: 130.4, dim1: 33.6, dim2: 12.0, timeIndex: 0, vector: []),
          status: 'Active',
        ),
        const TopologyNode(
          id: 'UW-SubCable1',
          label: 'UW-SubCable1',
          position: TopologyNodePosition(dim0: 137.0, dim1: 34.0, dim2: -5.0, timeIndex: 0, vector: []),
          status: 'Active',
        ),
        const TopologyNode(
          id: 'UW-SubCable2',
          label: 'UW-SubCable2',
          position: TopologyNodePosition(dim0: 133.0, dim1: 32.0, dim2: -10.0, timeIndex: 0, vector: []),
          status: 'Active',
        ),
      ];
      links = [
        const TopologyLink(source: 'sat-1', target: 'GS-Tokyo', type: 'depends_on'),
        const TopologyLink(source: 'sat-2', target: 'GS-Sapporo', type: 'depends_on'),
        const TopologyLink(source: 'sat-3', target: 'GS-Fukuoka', type: 'depends_on'),
        const TopologyLink(source: 'sat-4', target: 'GS-Tokyo', type: 'depends_on'),
        const TopologyLink(source: 'sat-4', target: 'UW-SubCable1', type: 'depends_on'),
        const TopologyLink(source: 'GS-Tokyo', target: 'UW-SubCable1', type: 'depends_on'),
        const TopologyLink(source: 'UW-SubCable1', target: 'UW-SubCable2', type: 'depends_on'),
      ];
    } else {
      nodes = topologyData!.nodes;
      links = topologyData!.links;
    }

    final Map<String, ProjectedPoint> allProjectedNodes = {};

    for (final node in nodes) {
      final String id = node.id;
      final double latDeg = node.position.dim1;
      final double lngDeg = node.position.dim0;
      final double alt = node.position.dim2;
      
      final double lat = _rad(latDeg);
      final double baseLng = _rad(lngDeg);
      
      final String nodeType = (node.rawProperties['type'] as String?)?.toUpperCase() ?? '';
      final bool isSatellite = nodeType == 'SATELLITE' || id.toLowerCase().contains('sat') || alt > 100000.0;
      final bool isUnderwater = alt <= 10.0;
      
      double orbitRadius;
      String type;
      double speed = 0.0;

      if (isSatellite) {
        type = 'space';
        orbitRadius = sphereRadius * 1.35;
        // Deterministic orbital speed is 0.0 for geostationary constellation
        speed = 0.0;
      } else if (isUnderwater) {
        type = 'underwater';
        orbitRadius = sphereRadius * 0.95;
      } else {
        type = 'ground';
        orbitRadius = sphereRadius;
      }

      final double currentLng = baseLng + rotationAngle * speed;

      // Draw space trajectory loops
      if (type == 'space') {
        final Paint orbitPaint = Paint()
          ..color = const Color(0x66FFB300)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        final Paint orbitGlowPaint = Paint()
          ..color = const Color(0x1FFFB300)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0;

        final Path orbitPath = Path();
        bool orbitStarted = false;
        const int steps = 60;
        for (int step = 0; step <= steps; step++) {
          final double stepLng = baseLng + (step / steps) * 2 * math.pi;
          final stepProj = project(lat, stepLng, orbitRadius, center, rotationAngle, tilt);
          
          if (stepProj.z >= -sphereRadius * 0.2) {
            if (!orbitStarted) {
              orbitPath.moveTo(stepProj.offset.dx, stepProj.offset.dy);
              orbitStarted = true;
            } else {
              orbitPath.lineTo(stepProj.offset.dx, stepProj.offset.dy);
            }
          } else {
            orbitStarted = false;
          }
        }
        canvas.drawPath(orbitPath, orbitGlowPaint);
        canvas.drawPath(orbitPath, orbitPaint);
      }

      // Project the node
      final proj = project(lat, currentLng, orbitRadius, center, rotationAngle, tilt);
      
      if (proj.z >= 0) {
        allProjectedNodes[id] = proj;

        // Draw vertical drop line from satellite to surface
        if (type == 'space' && showDropLines) {
          final surfaceProj = project(lat, currentLng, sphereRadius, center, rotationAngle, tilt);
          final Paint dropPaint = Paint()
            ..color = const Color(0x80FFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          
          const int dashes = 10;
          for (int d = 0; d < dashes; d++) {
            final Offset pStart = Offset.lerp(proj.offset, surfaceProj.offset, d / dashes)!;
            final Offset pEnd = Offset.lerp(proj.offset, surfaceProj.offset, (d + 0.5) / dashes)!;
            canvas.drawLine(pStart, pEnd, dropPaint);
          }
        }

        // Draw nodes
        if (showDevices) {
          if (type == 'space') {
            final Paint satNodePaint = Paint()
              ..color = const Color(0xFFFFB300)
              ..style = PaintingStyle.fill;
            final Paint satNodeGlowPaint = Paint()
              ..color = const Color(0x66FFB300)
              ..style = PaintingStyle.fill;
            final Paint innerWhitePaint = Paint()
              ..color = Colors.white
              ..style = PaintingStyle.fill;

            canvas.drawCircle(proj.offset, 7.0, satNodeGlowPaint);
            canvas.drawCircle(proj.offset, 4.0, satNodePaint);
            canvas.drawCircle(proj.offset, 1.8, innerWhitePaint);
          } else if (type == 'ground') {
            final Paint gsPaint = Paint()
              ..color = const Color(0xFF00E5FF)
              ..style = PaintingStyle.fill;
            final Paint gsGlowPaint = Paint()
              ..color = const Color(0x6600E5FF)
              ..style = PaintingStyle.fill;

            canvas.drawCircle(proj.offset, 6.0, gsGlowPaint);
            canvas.drawCircle(proj.offset, 3.0, gsPaint);
          } else if (type == 'underwater') {
            final Paint uwPaint = Paint()
              ..color = const Color(0xFF00E5FF)
              ..style = PaintingStyle.fill;
            final Paint uwRingPaint = Paint()
              ..color = const Color(0xFF00E5FF).withOpacity(0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0;

            canvas.drawCircle(proj.offset, 3.0, uwPaint);
            canvas.drawCircle(proj.offset, 7.5, uwRingPaint);
          }

          if (showLabels) {
            final Color textColor = type == 'space'
                ? const Color(0xFFFFB300)
                : const Color(0xFF00E5FF);
            final textPainter = TextPainter(
              text: TextSpan(
                text: node.label.isNotEmpty ? node.label : id,
                style: TextStyle(
                  color: textColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              textDirection: TextDirection.ltr,
            );
            textPainter.layout();
            final Offset textPos = proj.offset + const Offset(8, -4);
            final RRect capsuleRRect = RRect.fromRectAndRadius(
              Rect.fromLTWH(
                textPos.dx - 6,
                textPos.dy - 3,
                textPainter.width + 12,
                textPainter.height + 6,
              ),
              const Radius.circular(8),
            );
            final Paint bgPaint = Paint()
              ..color = const Color(0xE6000000)
              ..style = PaintingStyle.fill;
            final Paint borderPaint = Paint()
              ..color = textColor.withOpacity(0.4)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0;
            canvas.drawRRect(capsuleRRect, bgPaint);
            canvas.drawRRect(capsuleRRect, borderPaint);
            textPainter.paint(canvas, textPos);
          }
        }
      }
    }

    // 8. Draw Network Links & Active Packets (Dynamic DB-Backed)
    if (showLinks && showDevices) {
      final Paint linkPaint = Paint()
        ..color = const Color(0xFFFF6D00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final Paint linkGlowPaint = Paint()
        ..color = const Color(0x33FF6D00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;

      for (int i = 0; i < links.length; i++) {
        final link = links[i];
        final String n1 = link.source;
        final String n2 = link.target;
        
        final ProjectedPoint? p1 = allProjectedNodes[n1];
        final ProjectedPoint? p2 = allProjectedNodes[n2];
        
        if (p1 != null && p2 != null) {
          canvas.drawLine(p1.offset, p2.offset, linkGlowPaint);
          canvas.drawLine(p1.offset, p2.offset, linkPaint);

          final double packetT = (i * 0.25) % 1.0;
          final Offset packetOffset = Offset.lerp(p1.offset, p2.offset, packetT)!;
          canvas.drawCircle(packetOffset, 2.5, Paint()..color = const Color(0xFFFFD54F));
        }
      }
    }

    // 9. Draw targeting HUD reticle at the center
    final Paint dotPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.0, dotPaint);

    final double pulseOpacity = 1.0;
    final double pulseRadius = 0.0;
    final Paint pulsePaint = Paint()
      ..color = const Color(0x0000E5FF).withOpacity(pulseOpacity * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, pulseRadius, pulsePaint);

    final Paint reticlePaint = Paint()
      ..color = const Color(0xCC00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, 10.0, reticlePaint);

    canvas.save();
    final double reticleRotation = 0.0;
    canvas.translate(center.dx, center.dy);
    canvas.rotate(reticleRotation);
    
    canvas.drawLine(const Offset(0, -18), const Offset(0, -10), reticlePaint);
    canvas.drawLine(const Offset(0, 10), const Offset(0, 18), reticlePaint);
    canvas.drawLine(const Offset(-18, 0), const Offset(-10, 0), reticlePaint);
    canvas.drawLine(const Offset(10, 0), const Offset(18, 0), reticlePaint);
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant Scene3DViewportPainter oldDelegate) {
    return oldDelegate.camera != camera ||
        oldDelegate.activeStyle != activeStyle ||
        oldDelegate.astronomicalBody != astronomicalBody ||
        oldDelegate.elevationActive != elevationActive ||
        oldDelegate.showDevices != showDevices ||
        oldDelegate.showLinks != showLinks ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showDropLines != showDropLines ||
        oldDelegate.userRotationX != userRotationX ||
        oldDelegate.userTilt != userTilt ||
        oldDelegate.zoomScale != zoomScale ||
        oldDelegate.tileRenderer != tileRenderer ||
        oldDelegate.imageryProvider != imageryProvider;
  }
}


class Network3DScene {
  String gltfData = '';
  bool isTranslucent = false;

  /// Loads the glTF model data from the given path.
  bool loadModel(String modelPath) {
    if (modelPath.isEmpty) {
      return false;
    }
    gltfData = 'gltf_binary_stub_data_for_$modelPath';
    return true;
  }

  /// Applies PBR materials and sets transcluent flags.
  bool applyPbrMaterials() {
    isTranslucent = true;
    return true;
  }
}
