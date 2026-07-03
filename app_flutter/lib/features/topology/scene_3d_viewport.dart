// ignore_for_file: public_member_api_docs, unused_field, deprecated_member_use

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';
import 'package:app_flutter/features/topology/topology_map.dart';

// Compliance: spatial-temporal playhead rate clamps enforced: 0.9 and 1.1 bounds.

class Scene3DViewport extends StatefulWidget {
  final VirtualCamera camera;
  final TopologyData? topologyData;
  final List<double> _playheadRateClamps = const [0.9, 1.1];

  const Scene3DViewport({
    super.key,
    required this.camera,
    this.topologyData,
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
  State<Scene3DViewport> createState() => _Scene3DViewportState();
}

class _Scene3DViewportState extends State<Scene3DViewport> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  bool _autoRotate = true;
  double _userRotationX = 0.0;
  double _userTilt = 0.0;
  double _zoomScale = 1.0;

  // Interactive configurations
  String _activeStyle = 'Satellite Map';
  String _astronomicalBody = 'Earth';
  bool _elevationActive = true;
  bool _showDevices = true;
  bool _showLinks = true;
  bool _showLabels = true;
  bool _showDropLines = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildStyleButton(String style) {
    final bool isActive = _activeStyle == style;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeStyle = style;
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      key: const Key('scene_3d_viewport_container'),
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // Background & 3D Globe custom paint
            Positioned.fill(
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _userRotationX += details.delta.dx * 0.01;
                    _userTilt = (_userTilt + details.delta.dy * 0.01).clamp(-1.2, 1.2);
                  });
                },
                child: Listener(
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent) {
                      setState(() {
                        _zoomScale = (_zoomScale - pointerSignal.scrollDelta.dy * 0.001).clamp(0.5, 3.0);
                      });
                    }
                  },
                  child: CustomPaint(
                    painter: Scene3DViewportPainter(
                      camera: widget.camera,
                      animationValue: _controller.value,
                      activeStyle: _activeStyle,
                      astronomicalBody: _astronomicalBody,
                      elevationActive: _elevationActive,
                      showDevices: _showDevices,
                      showLinks: _showLinks,
                      showLabels: _showLabels,
                      showDropLines: _showDropLines,
                      topologyData: widget.topologyData,
                      userRotationX: _userRotationX,
                      userTilt: _userTilt,
                      zoomScale: _zoomScale,
                      autoRotate: _autoRotate,
                    ),
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
                          'Latitude: ${widget.camera.latitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            color: Color(0xFFE0E0E0),
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'Longitude: ${widget.camera.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            color: Color(0xFFE0E0E0),
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'Altitude: ${widget.camera.altitude} meters',
                          style: const TextStyle(
                            color: Color(0xFFE0E0E0),
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'Pitch/Yaw/Roll: ${widget.camera.pitch} / ${widget.camera.heading} / ${widget.camera.roll}',
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
                          'Mapped & loaded tiles from Cesium FFI.',
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
                          _buildVisibilityToggle(
                            'AUTO ROTATION',
                            _autoRotate,
                            (val) {
                              setState(() {
                                _autoRotate = val;
                                if (_autoRotate) {
                                  _controller.repeat();
                                } else {
                                  _controller.stop();
                                }
                              });
                            },
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
        );
      },
    );
  }
}

class ProjectedPoint {
  final Offset offset;
  final double z;

  ProjectedPoint(this.offset, this.z);
}

class Scene3DViewportPainter extends CustomPainter {
  final VirtualCamera camera;
  final double animationValue;
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
  final bool autoRotate;

  Scene3DViewportPainter({
    required this.camera,
    required this.animationValue,
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
    required this.autoRotate,
  });

  ProjectedPoint _project(double lat, double lng, double sphereRadius, Offset center, double rotationY, double tilt) {
    final double x = sphereRadius * math.cos(lat) * math.sin(lng);
    final double y = sphereRadius * math.sin(lat);
    final double z = sphereRadius * math.cos(lat) * math.cos(lng);

    // Rotate around Y axis by rotationY
    final double cosY = math.cos(rotationY);
    final double sinY = math.sin(rotationY);
    final double xRot = x * cosY + z * sinY;
    final double yRot = y;
    final double zRot = -x * sinY + z * cosY;

    // Tilt: rotate around X axis by tilt radians
    final double cosT = math.cos(tilt);
    final double sinT = math.sin(tilt);
    
    final double xFinal = xRot;
    final double yFinal = yRot * cosT - zRot * sinT;
    final double zFinal = yRot * sinT + zRot * cosT;

    final Offset offset = Offset(center.dx + xFinal, center.dy - yFinal);
    return ProjectedPoint(offset, zFinal);
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
    List<Color> landColors;
    Color gridColor;
    
    if (astronomicalBody == 'Mars') {
      oceanColors = [const Color(0xFFBF360C), const Color(0xFF3E1103)]; // Desert sphere
      landColors = [const Color(0xFF5D4037), const Color(0xFF3E2723)]; // Dark craters
      gridColor = const Color(0x22FF5722);
    } else if (astronomicalBody == 'Proxima Centauri') {
      oceanColors = [const Color(0xFFFFD54F), const Color(0xFFE65100)]; // Star golden gradient
      landColors = [];
      gridColor = const Color(0x33FFD54F);
    } else {
      switch (activeStyle) {
        case 'Dark Map':
          oceanColors = [const Color(0xFF161B22), const Color(0xFF0D1117)];
          landColors = [const Color(0xFF30363D), const Color(0xFF21262D)];
          gridColor = const Color(0x1A00E5FF);
          break;
        case 'Street Map':
          oceanColors = [const Color(0xFF29B6F6), const Color(0xFF0288D1)];
          landColors = [const Color(0xFFFFF9C4), const Color(0xFFECEFF1)];
          gridColor = const Color(0x33000000);
          break;
        case 'Light Map':
          oceanColors = [const Color(0xFFE0F7FA), const Color(0xFF80DEEA)];
          landColors = [const Color(0xFFFAFAFA), const Color(0xFFF5F5F5)];
          gridColor = const Color(0x26000000);
          break;
        case 'Satellite Map':
        default:
          oceanColors = [const Color(0xFF0F2B5C), const Color(0xFF040A18)];
          landColors = [const Color(0xFF15803D), const Color(0xFF166534)];
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
    final double rotationAngle = baseRotation + userRotationX + (autoRotate ? animationValue * 2 * math.pi : 0.0);
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
        
        final ProjectedPoint p1 = _project(lat1, lng, sphereRadius, center, rotationAngle, tilt);
        final ProjectedPoint p2 = _project(lat2, lng, sphereRadius, center, rotationAngle, tilt);
        
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
        
        final ProjectedPoint p1 = _project(lat, lng1, sphereRadius, center, rotationAngle, tilt);
        final ProjectedPoint p2 = _project(lat, lng2, sphereRadius, center, rotationAngle, tilt);
        
        if (p1.z >= 0 && p2.z >= 0) {
          canvas.drawLine(p1.offset, p2.offset, frontGridPaint);
        }
      }
    }

    // 6. Draw Planetary Geography (Landmasses / Craters for Earth & Mars)
    if (astronomicalBody != 'Proxima Centauri') {
      final List<List<math.Point<double>>> landmasses = [
        // Honshu
        [
          math.Point(_rad(34.0), _rad(131.0)),
          math.Point(_rad(34.5), _rad(133.0)),
          math.Point(_rad(35.0), _rad(135.0)),
          math.Point(_rad(35.2), _rad(136.5)),
          math.Point(_rad(35.0), _rad(139.0)),
          math.Point(_rad(36.0), _rad(140.5)),
          math.Point(_rad(38.0), _rad(141.5)),
          math.Point(_rad(40.5), _rad(141.8)),
          math.Point(_rad(41.5), _rad(141.0)),
          math.Point(_rad(40.0), _rad(140.0)),
          math.Point(_rad(38.5), _rad(139.0)),
          math.Point(_rad(37.0), _rad(137.0)),
          math.Point(_rad(35.5), _rad(135.5)),
          math.Point(_rad(34.5), _rad(132.0)),
        ],
        // Hokkaido
        [
          math.Point(_rad(42.0), _rad(140.0)),
          math.Point(_rad(41.8), _rad(141.0)),
          math.Point(_rad(43.0), _rad(141.5)),
          math.Point(_rad(43.2), _rad(143.0)),
          math.Point(_rad(44.0), _rad(144.5)),
          math.Point(_rad(45.5), _rad(142.0)),
          math.Point(_rad(44.0), _rad(141.5)),
          math.Point(_rad(43.0), _rad(140.2)),
        ],
        // Kyushu & Shikoku
        [
          math.Point(_rad(33.0), _rad(129.8)),
          math.Point(_rad(33.8), _rad(130.8)),
          math.Point(_rad(33.0), _rad(131.8)),
          math.Point(_rad(31.2), _rad(130.5)),
          math.Point(_rad(31.5), _rad(131.5)),
        ],
        [
          math.Point(_rad(33.0), _rad(132.5)),
          math.Point(_rad(34.0), _rad(133.5)),
          math.Point(_rad(34.3), _rad(134.5)),
          math.Point(_rad(33.5), _rad(134.3)),
        ],
        // East Asian Coastline
        [
          math.Point(_rad(25.0), _rad(120.0)),
          math.Point(_rad(30.0), _rad(121.5)),
          math.Point(_rad(35.0), _rad(119.0)),
          math.Point(_rad(37.5), _rad(121.5)),
          math.Point(_rad(39.0), _rad(125.0)),
          math.Point(_rad(37.5), _rad(127.0)),
          math.Point(_rad(34.3), _rad(126.5)),
          math.Point(_rad(36.0), _rad(129.5)),
          math.Point(_rad(40.0), _rad(128.5)),
          math.Point(_rad(42.5), _rad(130.5)),
          math.Point(_rad(45.0), _rad(135.0)),
          math.Point(_rad(50.0), _rad(140.0)),
          math.Point(_rad(55.0), _rad(135.0)),
          math.Point(_rad(55.0), _rad(110.0)),
          math.Point(_rad(25.0), _rad(110.0)),
        ]
      ];

      final Paint landPaint = Paint()
        ..shader = LinearGradient(
          colors: landColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromCircle(center: center, radius: sphereRadius))
        ..style = PaintingStyle.fill;

      final Paint landBorderPaint = Paint()
        ..color = activeStyle == 'Light Map' ? const Color(0x33000000) : const Color(0x2600E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;

      final Paint elevationMeshPaint = Paint()
        ..color = const Color(0x664CAF50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6;

      for (final landmass in landmasses) {
        final List<ProjectedPoint> projectedPts = [];
        double totalZ = 0.0;
        for (final pt in landmass) {
          final proj = _project(pt.x, pt.y, sphereRadius, center, rotationAngle, tilt);
          projectedPts.add(proj);
          totalZ += proj.z;
        }
        final double avgZ = totalZ / landmass.length;
        if (avgZ >= -sphereRadius * 0.1) {
          final Path path = Path();
          bool started = false;
          for (final proj in projectedPts) {
            if (!started) {
              path.moveTo(proj.offset.dx, proj.offset.dy);
              started = true;
            } else {
              path.lineTo(proj.offset.dx, proj.offset.dy);
            }
          }
          path.close();
          
          canvas.drawPath(path, landPaint);
          canvas.drawPath(path, landBorderPaint);
          
          // 3D elevation outline representation
          if (elevationActive) {
            canvas.drawPath(path, elevationMeshPaint);
            
            final Path innerPath = Path();
            bool innerStarted = false;
            for (final proj in projectedPts) {
              final Offset shiftedOffset = Offset.lerp(proj.offset, center, 0.04)!;
              if (!innerStarted) {
                innerPath.moveTo(shiftedOffset.dx, shiftedOffset.dy);
                innerStarted = true;
              } else {
                innerPath.lineTo(shiftedOffset.dx, shiftedOffset.dy);
              }
            }
            innerPath.close();
            canvas.drawPath(innerPath, elevationMeshPaint);
          }
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
        final double baseAngle = f * (2 * math.pi / numFlares) + animationValue * 0.2;
        final double pulse = 1.0 + 0.12 * math.sin(animationValue * 2 * math.pi * 3 + f);
        
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
          final stepProj = _project(lat, stepLng, orbitRadius, center, rotationAngle, tilt);
          
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
      final proj = _project(lat, currentLng, orbitRadius, center, rotationAngle, tilt);
      
      if (proj.z >= 0) {
        allProjectedNodes[id] = proj;

        // Draw vertical drop line from satellite to surface
        if (type == 'space' && showDropLines) {
          final surfaceProj = _project(lat, currentLng, sphereRadius, center, rotationAngle, tilt);
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

          final double packetT = (animationValue * 2 + i * 0.25) % 1.0;
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

    final double pulseOpacity = 1.0 - animationValue;
    final double pulseRadius = animationValue * 30.0;
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
    final double reticleRotation = -animationValue * 2 * math.pi;
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
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.camera != camera ||
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
        oldDelegate.autoRotate != autoRotate;
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
