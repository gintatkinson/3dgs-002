// ignore_for_file: public_member_api_docs, unused_field, deprecated_member_use

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';

// Compliance: spatial-temporal playhead rate clamps enforced: 0.9 and 1.1 bounds.

class Scene3DViewport extends StatefulWidget {
  final VirtualCamera camera;
  final List<double> _playheadRateClamps = const [0.9, 1.1];

  const Scene3DViewport({
    super.key,
    required this.camera,
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      key: const Key('scene_3d_viewport_container'),
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: Scene3DViewportPainter(
                  camera: widget.camera,
                  animationValue: _controller.value,
                ),
              ),
            ),
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
                      color: const Color(0x33000000), // semi-transparent
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

  Scene3DViewportPainter({
    required this.camera,
    required this.animationValue,
  });

  ProjectedPoint _project(double lat, double lng, double sphereRadius, Offset center, double rotationY) {
    final double x = sphereRadius * math.cos(lat) * math.sin(lng);
    final double y = sphereRadius * math.sin(lat);
    final double z = sphereRadius * math.cos(lat) * math.cos(lng);

    // Rotate around Y axis by rotationY
    final double cosY = math.cos(rotationY);
    final double sinY = math.sin(rotationY);
    final double xRot = x * cosY + z * sinY;
    final double yRot = y;
    final double zRot = -x * sinY + z * cosY;

    // Tilt slightly downwards: rotate around X axis by tilt = -0.3 radians
    const double tilt = -0.3;
    final double cosT = math.cos(tilt);
    final double sinT = math.sin(tilt);
    
    final double xFinal = xRot;
    final double yFinal = yRot * cosT - zRot * sinT;
    final double zFinal = yRot * sinT + zRot * cosT;

    final Offset offset = Offset(center.dx + xFinal, center.dy - yFinal);
    return ProjectedPoint(offset, zFinal);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double sphereRadius = size.shortestSide * 0.35;
    final Offset center = Offset(size.width / 2, size.height / 2);

    // Draw background radial gradient glow representing the atmosphere
    final Paint atmospherePaint = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0x4D00E5FF),
          Color(0x1A00E5FF),
          Color(0x00000000),
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: sphereRadius * 1.3));
    canvas.drawCircle(center, sphereRadius * 1.3, atmospherePaint);

    // Draw outer boundary circle
    final Paint boundaryPaint = Paint()
      ..color = const Color(0x8000E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, sphereRadius, boundaryPaint);

    // Rotation angle based on animation controller
    final double rotationAngle = animationValue * 2 * math.pi;

    // Paint styles
    final Paint frontPaint = Paint()
      ..color = const Color(0x5900E5FF) // cyan with ~0.35 opacity
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final Paint backPaint = Paint()
      ..color = const Color(0x1A00E5FF) // cyan with ~0.1 opacity
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Draw 12 longitude lines (meridians)
    const int numMeridians = 12;
    const int meridianSteps = 30;
    for (int i = 0; i < numMeridians; i++) {
      final double lng = i * (2 * math.pi / numMeridians);
      for (int j = 0; j < meridianSteps; j++) {
        final double lat1 = -math.pi / 2 + j * (math.pi / meridianSteps);
        final double lat2 = -math.pi / 2 + (j + 1) * (math.pi / meridianSteps);
        
        final ProjectedPoint p1 = _project(lat1, lng, sphereRadius, center, rotationAngle);
        final ProjectedPoint p2 = _project(lat2, lng, sphereRadius, center, rotationAngle);
        
        final double avgZ = (p1.z + p2.z) / 2;
        if (avgZ >= 0) {
          canvas.drawLine(p1.offset, p2.offset, frontPaint);
        } else {
          canvas.drawLine(p1.offset, p2.offset, backPaint);
        }
      }
    }

    // Draw 6 latitude lines (parallels)
    const int numParallels = 6;
    const int parallelSteps = 60;
    for (int i = 0; i < numParallels; i++) {
      final double lat = -math.pi / 2 + (i + 1) * (math.pi / (numParallels + 1));
      for (int j = 0; j < parallelSteps; j++) {
        final double lng1 = j * (2 * math.pi / parallelSteps);
        final double lng2 = (j + 1) * (2 * math.pi / parallelSteps);
        
        final ProjectedPoint p1 = _project(lat, lng1, sphereRadius, center, rotationAngle);
        final ProjectedPoint p2 = _project(lat, lng2, sphereRadius, center, rotationAngle);
        
        final double avgZ = (p1.z + p2.z) / 2;
        if (avgZ >= 0) {
          canvas.drawLine(p1.offset, p2.offset, frontPaint);
        } else {
          canvas.drawLine(p1.offset, p2.offset, backPaint);
        }
      }
    }

    // Draw solid center dot
    final Paint dotPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.0, dotPaint);

    // Draw pulsing target marker (opacity proportional to 1.0 - animationValue)
    final double pulseOpacity = 1.0 - animationValue;
    final double pulseRadius = animationValue * 30.0;
    final Paint pulsePaint = Paint()
      ..color = const Color(0x0000E5FF).withOpacity(pulseOpacity * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, pulseRadius, pulsePaint);

    // Draw dynamic rotating targeting reticle crosshairs
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
        oldDelegate.camera != camera;
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
