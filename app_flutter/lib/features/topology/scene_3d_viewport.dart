import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';
import 'package:app_flutter/features/topology/cesium_globe_viewport.dart';
import 'package:app_flutter/features/topology/topology_map.dart';

class Scene3DViewport extends StatefulWidget {
  final VirtualCamera camera;
  final TopologyData? topologyData;
  final List<double> _playheadRateClamps = const [0.9, 1.1];

  const Scene3DViewport({
    super.key,
    required this.camera,
    this.topologyData,
  });

  @override
  State<Scene3DViewport> createState() => _Scene3DViewportState();
}

class _Scene3DViewportState extends State<Scene3DViewport> {
  late VirtualCamera _camera;

  String _activeStyle = 'Satellite Map';
  bool _elevationActive = true;
  bool _showDevices = true;
  bool _showLinks = true;
  bool _showLabels = true;
  bool _showDropLines = true;

  @override
  void initState() {
    super.initState();
    _camera = widget.camera;
  }

  @override
  void didUpdateWidget(covariant Scene3DViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.camera != oldWidget.camera) {
      _camera = widget.camera;
    }
  }

  void _onCameraChanged(VirtualCamera camera) {
    _camera = camera;
    setState(() {});
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
    return Stack(
      key: const Key('scene_3d_viewport_container'),
      children: [
        Positioned.fill(
          child: CesiumGlobeViewport(
            camera: _camera,
            topologyData: widget.topologyData,
            mapStyle: _activeStyle,
            elevationActive: _elevationActive,
            showDevices: _showDevices,
            showLinks: _showLinks,
            showLabels: _showLabels,
            showDropLines: _showDropLines,
            onCameraChanged: _onCameraChanged,
          ),
        ),

        // Left HUD (Camera Stats)
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
                  color: const Color(0x990A0E1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0x33FFFFFF),
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
                      'Latitude: ${_camera.latitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        color: Color(0xFFE0E0E0),
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Longitude: ${_camera.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        color: Color(0xFFE0E0E0),
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Altitude: ${_camera.altitude.toStringAsFixed(0)} meters',
                      style: const TextStyle(
                        color: Color(0xFFE0E0E0),
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Pitch/Yaw/Roll: ${_camera.pitch.toStringAsFixed(0)} / ${_camera.heading.toStringAsFixed(0)} / ${_camera.roll.toStringAsFixed(0)}',
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
                      'Cesium 3D Globe (WebView)',
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

        // Right HUD: Map Configuration Panel
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
                  color: const Color(0x990A0E1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0x3300E5FF),
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
                              _camera = widget.camera;
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
  }
}
