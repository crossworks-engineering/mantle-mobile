// A VoiceRecorder that records what was asked of it instead of audio. The
// `record` plugin has no platform under test, so every voice test drives
// VoiceCapture through this.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart' show Fake;
import 'package:jackdaw/features/voice/voice_capture.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakeVoiceRecorder implements VoiceRecorder {
  FakeVoiceRecorder({this.permitted = true, this.stopPath = '/tmp/fake.m4a'});

  bool permitted;
  bool failStart = false;

  /// What [stop] answers; null means "nothing was recorded".
  String? stopPath;

  /// When set, [start] waits on it — for the release-before-started race.
  Completer<void>? startGate;

  int starts = 0;
  int stops = 0;
  int cancels = 0;
  bool disposed = false;
  String? lastPath;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<void> start(String path) async {
    if (startGate != null) await startGate!.future;
    if (failStart) throw StateError('no recorder');
    starts++;
    lastPath = path;
  }

  @override
  Future<String?> stop() async {
    stops++;
    return stopPath;
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

/// path_provider has no platform under test either; VoiceCapture asks it for
/// the temp directory before every recording. Call once in `setUpAll`.
void installFakeTempDirectory() {
  PathProviderPlatform.instance = _FakePathProvider();
}

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
}
