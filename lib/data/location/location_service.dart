import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'location_ping.dart';

part 'location_service.g.dart';

/// Device location, wrapping **geolocator** + **battery_plus**. Permission is
/// *when-in-use* (requested when the user opts in, in settings); [currentPing]
/// only ever reads — it returns null rather than prompting, so a send never
/// triggers a permission dialog.
class LocationService {
  const LocationService();

  bool _granted(LocationPermission p) =>
      p == LocationPermission.always || p == LocationPermission.whileInUse;

  /// True if when-in-use location is already granted (no prompt).
  Future<bool> hasPermission() async =>
      _granted(await Geolocator.checkPermission());

  /// Prompt for when-in-use permission (the opt-in toggle calls this). Returns
  /// whether it ended up granted. False if location services are off.
  Future<bool> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return _granted(p);
  }

  /// The freshest fix as a [LocationPing], or null if permission isn't granted
  /// or no fix is available. Best-effort and time-bounded: a short
  /// [getCurrentPosition] then last-known fallback, so a send is never held
  /// waiting for a perfect fix (the agent caveats a stale one).
  Future<LocationPing?> currentPing() async {
    if (!await hasPermission()) return null;

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );
    } catch (_) {
      // Timed out / services hiccup — fall back to whatever's cached.
      try {
        pos = await Geolocator.getLastKnownPosition();
      } catch (_) {
        pos = null;
      }
    }
    if (pos == null) return null;

    int? battery;
    try {
      battery = await Battery().batteryLevel; // 0..100
    } catch (_) {
      battery = null;
    }

    return LocationPing(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: pos.timestamp,
      accuracy: pos.accuracy,
      altitude: pos.altitude,
      altitudeAccuracy: pos.altitudeAccuracy,
      speed: pos.speed,
      heading: pos.heading,
      batteryPercent: (battery != null && battery >= 0) ? battery : null,
      // geolocator doesn't expose the provider; pick sensibly per platform.
      source: defaultTargetPlatform == TargetPlatform.android ? 'fused' : 'gps',
      isMock: pos.isMocked,
    );
  }
}

@Riverpod(keepAlive: true)
LocationService locationService(Ref ref) => const LocationService();
