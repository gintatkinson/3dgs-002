import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/domain/cesium_3d/camera_controller.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';

void main() {
  group('CameraController', () {
    VirtualCamera _makeCam({
      double lat = 35.0,
      double lng = 135.0,
      double alt = 500.0,
      double heading = 0.0,
      double pitch = 0.0,
      double roll = 0.0,
    }) {
      return VirtualCamera.clamped(
        latitude: lat,
        longitude: lng,
        altitude: alt,
        heading: heading,
        pitch: pitch,
        roll: roll,
      );
    }

    test('pan changes lat/lng', () {
      final c = CameraController(_makeCam());
      c.pan(const Offset(100, 50));
      final cam = c.current;
      expect(cam.longitude, greaterThan(135.0));
      expect(cam.latitude, greaterThan(35.0));
    });

    test('tilt changes pitch/heading, not lat/lng', () {
      final c = CameraController(_makeCam(pitch: -45));
      final before = c.current;
      c.tilt(const Offset(0, 100));
      final after = c.current;
      expect(after.pitch, lessThan(before.pitch));
      expect(after.latitude, equals(before.latitude));
      expect(after.longitude, equals(before.longitude));
    });

    test('rotateHeading changes heading only', () {
      final c = CameraController(_makeCam());
      c.rotateHeading(const Offset(100, 50));
      final after = c.current;
      expect(after.heading, isNot(0));
      expect(after.latitude, equals(35.0));
      expect(after.pitch, equals(0.0));
    });

    test('shift+drag (tilt) modifies pitch and heading, not lat/lng', () {
      final c = CameraController(_makeCam(pitch: -45, heading: 90));
      final before = c.current;
      c.tilt(const Offset(20, 80));
      final after = c.current;
      expect(after.pitch, isNot(before.pitch));
      expect(after.heading, isNot(before.heading));
      expect(after.latitude, equals(before.latitude));
      expect(after.longitude, equals(before.longitude));
    });

    test('ctrl+drag (rotateHeading) modifies heading, not lat/lng/pitch', () {
      final c = CameraController(_makeCam(pitch: -30));
      final before = c.current;
      c.rotateHeading(const Offset(50, 100));
      final after = c.current;
      expect(after.heading, isNot(before.heading));
      expect(after.latitude, equals(before.latitude));
      expect(after.longitude, equals(before.longitude));
      expect(after.pitch, equals(before.pitch));
    });

    test('zoom changes altitude', () {
      final c = CameraController(_makeCam());
      c.zoom(-200);
      expect(c.current.altitude, lessThan(500.0));
    });

    test('heading wraps at 360', () {
      final c = CameraController(_makeCam(heading: 358));
      c.rotateHeading(const Offset(100, 0));
      expect(c.current.heading, lessThan(360));
      expect(c.current.heading, greaterThan(340));
    });

    test('longitude wraps around -180/+180 boundary', () {
      final c = CameraController(_makeCam(lng: -175));
      c.pan(const Offset(-100, 0));
      expect(c.current.longitude, lessThan(180));
      expect(c.current.longitude, greaterThan(155));
    });

    test('keyboardRotate changes longitude only', () {
      final c = CameraController(_makeCam());
      c.keyboardRotate(10);
      expect(c.current.longitude, equals(145.0));
      expect(c.current.latitude, equals(35.0));
    });

    test('keyboardTilt changes pitch only', () {
      final c = CameraController(_makeCam());
      c.keyboardTilt(5);
      expect(c.current.pitch, equals(5.0));
    });

    test('zoom clamps to minAltitude', () {
      final c = CameraController(_makeCam(alt: 200));
      c.zoom(-10000);
      expect(c.current.altitude, equals(CameraController.minAltitude));
    });

    test('zoom clamps to maxAltitude', () {
      final c = CameraController(_makeCam());
      c.zoom(1000000000);
      expect(c.current.altitude, equals(CameraController.maxAltitude));
    });
  });

  group('VirtualCamera equality', () {
    test('identical cameras compare equal', () {
      final a = VirtualCamera(latitude: 35, longitude: 135, altitude: 500, heading: 0, pitch: -45, roll: 0);
      final b = VirtualCamera(latitude: 35, longitude: 135, altitude: 500, heading: 0, pitch: -45, roll: 0);
      expect(a, equals(b));
    });
    test('different values compare not equal', () {
      final a = VirtualCamera(latitude: 35, longitude: 135, altitude: 500, heading: 0, pitch: -45, roll: 0);
      final b = VirtualCamera(latitude: 36, longitude: 135, altitude: 500, heading: 0, pitch: -45, roll: 0);
      expect(a, isNot(equals(b)));
    });
  });
}
