import 'dart:ui';
import 'virtual_camera.dart';

class CameraController {
  VirtualCamera _camera;

  static const double dragSensitivity = 0.15;
  static const double scrollSensitivity = 0.5;
  static const double keyboardStep = 5.0;
  static const double minAltitude = 100.0;
  static const double maxAltitude = 40000000.0;
  static const double minPitch = -89.0;
  static const double maxPitch = 89.0;

  CameraController(this._camera);

  VirtualCamera get current => _camera;

  void updateCamera(VirtualCamera camera) {
    _camera = camera;
  }

  void pan(Offset delta) {
    final newLat = (_camera.latitude - delta.dy * dragSensitivity).clamp(-90.0, 90.0);
    final newLng = _wrapLng(_camera.longitude - delta.dx * dragSensitivity);
    _camera = VirtualCamera.clamped(
      latitude: newLat, longitude: newLng,
      altitude: _camera.altitude, heading: _camera.heading,
      pitch: _camera.pitch, roll: _camera.roll,
    );
  }

  void tilt(Offset delta) {
    _camera = VirtualCamera.clamped(
      latitude: _camera.latitude, longitude: _camera.longitude,
      altitude: _camera.altitude,
      heading: _wrapHeading(_camera.heading - delta.dx * dragSensitivity),
      pitch: (_camera.pitch - delta.dy * dragSensitivity).clamp(minPitch, maxPitch),
      roll: _camera.roll,
    );
  }

  void rotateHeading(Offset delta) {
    _camera = VirtualCamera.clamped(
      latitude: _camera.latitude, longitude: _camera.longitude,
      altitude: _camera.altitude,
      heading: _wrapHeading(_camera.heading - delta.dx * dragSensitivity),
      pitch: _camera.pitch, roll: _camera.roll,
    );
  }

  void zoom(double scrollDelta) {
    final newAlt = (_camera.altitude + scrollDelta * scrollSensitivity).clamp(minAltitude, maxAltitude);
    _camera = VirtualCamera.clamped(
      latitude: _camera.latitude, longitude: _camera.longitude,
      altitude: newAlt, heading: _camera.heading,
      pitch: _camera.pitch, roll: _camera.roll,
    );
  }

  void keyboardRotate(double degrees) {
    _camera = VirtualCamera.clamped(
      latitude: _camera.latitude, longitude: _wrapLng(_camera.longitude + degrees),
      altitude: _camera.altitude, heading: _camera.heading,
      pitch: _camera.pitch, roll: _camera.roll,
    );
  }

  void keyboardTilt(double degrees) {
    _camera = VirtualCamera.clamped(
      latitude: _camera.latitude, longitude: _camera.longitude,
      altitude: _camera.altitude, heading: _camera.heading,
      pitch: (_camera.pitch + degrees).clamp(minPitch, maxPitch),
      roll: _camera.roll,
    );
  }

  double _wrapLng(double lng) {
    while (lng > 180) lng -= 360;
    while (lng < -180) lng += 360;
    return lng;
  }

  double _wrapHeading(double heading) {
    while (heading > 360) heading -= 360;
    while (heading < 0) heading += 360;
    return heading;
  }
}
