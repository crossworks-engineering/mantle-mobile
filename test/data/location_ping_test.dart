// LocationPing wire serialization (Mantle's `location` field on a chat turn).

import 'package:flutter_test/flutter_test.dart';
import 'package:mantle_companion/data/location/location_ping.dart';

void main() {
  test('toJson sends required coords + ISO timestamp, omits null optionals', () {
    final json = LocationPing(
      latitude: -33.9249,
      longitude: 18.4241,
      timestamp: DateTime.utc(2026, 6, 21, 14, 30),
      accuracy: 8,
      batteryPercent: 84,
      source: 'fused',
      isMock: false,
    ).toJson();

    expect(json['latitude'], -33.9249);
    expect(json['longitude'], 18.4241);
    expect(json['timestamp'], '2026-06-21T14:30:00.000Z');
    expect(json['accuracy'], 8);
    expect(json['battery'], 84); // 0..100; server normalises
    expect(json['source'], 'fused');
    expect(json['isMock'], false);
    // Unset optionals are omitted, not sent as null.
    expect(json.containsKey('altitude'), isFalse);
    expect(json.containsKey('speed'), isFalse);
    expect(json.containsKey('heading'), isFalse);
  });

  test('a local timestamp is normalised to UTC', () {
    final json = LocationPing(
      latitude: 1,
      longitude: 2,
      timestamp: DateTime.utc(2026, 1, 1, 0, 0, 0),
    ).toJson();
    expect(json['timestamp'], endsWith('Z'));
  });
}
