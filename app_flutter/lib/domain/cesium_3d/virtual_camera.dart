class CoordinateValidationException implements Exception {
  final String message;

  CoordinateValidationException(this.message);

  @override
  String toString() => 'CoordinateValidationException: $message';
}

class VirtualCamera {
  final double latitude;
  final double longitude;
  final double altitude;
  final double heading;
  final double pitch;
  final double roll;

  VirtualCamera({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.heading,
    required this.pitch,
    required this.roll,
  }) {
    if (latitude < -90.0 || latitude > 90.0) {
      throw CoordinateValidationException('Latitude must be in the range [-90.0, 90.0].');
    }
    if (longitude < -180.0 || longitude > 180.0) {
      throw CoordinateValidationException('Longitude must be in the range [-180.0, 180.0].');
    }
    if (altitude < -100.0) {
      throw CoordinateValidationException('Altitude must be greater than or equal to -100.0 meters.');
    }
  }

  /// Creates a copy of VirtualCamera with clamped values if they exceed boundaries.
  /// Clamps altitude to at least -100.0, latitude to [-90, 90], and longitude to [-180, 180].
  factory VirtualCamera.clamped({
    required double latitude,
    required double longitude,
    required double altitude,
    required double heading,
    required double pitch,
    required double roll,
  }) {
    final double clampedLat = latitude.clamp(-90.0, 90.0);
    final double clampedLng = longitude.clamp(-180.0, 180.0);
    final double clampedAlt = altitude < -100.0 ? -100.0 : altitude;
    return VirtualCamera(
      latitude: clampedLat,
      longitude: clampedLng,
      altitude: clampedAlt,
      heading: heading,
      pitch: pitch,
      roll: roll,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VirtualCamera) return false;
    return other.latitude == latitude &&
        other.longitude == longitude &&
        other.altitude == altitude &&
        other.heading == heading &&
        other.pitch == pitch &&
        other.roll == roll;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude, altitude, heading, pitch, roll);

  @override
  String toString() {
    return 'VirtualCamera(latitude: $latitude, longitude: $longitude, altitude: $altitude, heading: $heading, pitch: $pitch, roll: $roll)';
  }
}
