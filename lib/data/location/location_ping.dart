/// A single device location fix, shaped to Mantle's `LocationPing` wire schema
/// (`packages/content/src/location-ping.ts`). Attached to a chat turn as the
/// `location` field. Only [latitude]/[longitude] are required; the server
/// sanitises and drops anything malformed, so we send whatever the platform
/// gives us. See docs: handover-companion-location.md.
class LocationPing {
  const LocationPing({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.altitude,
    this.altitudeAccuracy,
    this.speed,
    this.heading,
    this.batteryPercent,
    this.source,
    this.isMock,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy; // metres, horizontal radius
  final double? altitude; // metres ASL
  final double? altitudeAccuracy; // metres
  final double? speed; // m/s
  final double? heading; // degrees 0..360
  final int? batteryPercent; // 0..100 — server normalises to a 0..1 fraction
  final String? source; // gps | network | fused | other
  final bool? isMock;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toUtc().toIso8601String(),
        if (accuracy != null) 'accuracy': accuracy,
        if (altitude != null) 'altitude': altitude,
        if (altitudeAccuracy != null) 'altitudeAccuracy': altitudeAccuracy,
        if (speed != null) 'speed': speed,
        if (heading != null) 'heading': heading,
        if (batteryPercent != null) 'battery': batteryPercent,
        if (source != null) 'source': source,
        if (isMock != null) 'isMock': isMock,
      };
}
