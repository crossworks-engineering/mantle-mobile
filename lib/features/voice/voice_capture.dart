import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show DioException;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/chat/chat_repository.dart';

part 'voice_capture.g.dart';

/// The slice of a recorder [VoiceCapture] uses, behind an interface so the
/// state machine runs in tests without a platform. The real one is
/// [RecordVoiceRecorder].
abstract class VoiceRecorder {
  Future<bool> hasPermission();
  Future<void> start(String path);

  /// Stops and returns the path of the finished file (null when nothing was
  /// recorded).
  Future<String?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

/// The `record` package's recorder. Built lazily on the first [start]:
/// `AudioRecorder()` talks to the platform from its constructor, and a field
/// that merely shows a mic must not.
class RecordVoiceRecorder implements VoiceRecorder {
  AudioRecorder? _inner;
  AudioRecorder get _recorder => _inner ??= AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) =>
      _recorder.start(const RecordConfig(), path: path);

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() async => _inner?.dispose();
}

typedef VoiceRecorderFactory = VoiceRecorder Function();
typedef VoiceTranscriber = Future<String> Function(String audioPath);

/// Makes a recorder per [VoiceCapture]. Tests override it with a fake.
@Riverpod(keepAlive: true)
VoiceRecorderFactory voiceRecorderFactory(Ref ref) => RecordVoiceRecorder.new;

/// The app's one speech-to-text path: `POST /api/assistant/transcribe`
/// through the brain's default STT worker (the same pipeline as Telegram
/// voice notes). Read at transcribe time, never at build, so a screen that
/// only shows a mic does not build the chat repository.
@Riverpod(keepAlive: true)
VoiceTranscriber voiceTranscriber(Ref ref) =>
    ref.watch(chatRepositoryProvider).transcribe;

/// Whether the brain can transcribe at all. Flips to false for the rest of
/// the session on the first 412 ("no default STT worker configured"); every
/// mic watches it and hides, so a brain without a worker says so once
/// instead of failing on every hold.
@Riverpod(keepAlive: true)
class SttAvailability extends _$SttAvailability {
  @override
  bool build() => true;

  void markUnavailable() => state = false;
}

enum VoiceCaptureState { idle, recording, transcribing }

/// Why a capture failed, in the words the field shows.
@immutable
class VoiceCaptureError implements Exception {
  const VoiceCaptureError(this.message, {this.sttUnavailable = false});

  final String message;

  /// The server answered 412: no STT worker. The session hides the mic.
  final bool sttUnavailable;

  @override
  String toString() => 'VoiceCaptureError($message)';
}

/// One dictation: permission → record to a temp `.m4a` → stop → transcribe
/// → [onTranscript]. Owns the recorder, the elapsed ticker, the cap that
/// stops a forgotten recording, and the guard that makes a release before
/// the recorder actually started a safe no-op. Errors go to [onError] as a
/// [VoiceCaptureError]; a 412 is marked [VoiceCaptureError.sttUnavailable].
///
/// Listeners (the button) rebuild on every state or elapsed change.
class VoiceCapture extends ChangeNotifier {
  VoiceCapture({
    required VoiceRecorder recorder,
    required VoiceTranscriber transcribe,
    required this.onTranscript,
    required this.onError,
    this.maxDuration = const Duration(seconds: 60),
    Future<Directory> Function()? tempDirectory,
  })  // Named parameters cannot be `this._private`, so the lint's fix
      // does not apply here.
      // ignore: prefer_initializing_formals
      : _recorder = recorder,
        // ignore: prefer_initializing_formals
        _transcribe = transcribe,
        _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  final VoiceRecorder _recorder;
  final VoiceTranscriber _transcribe;
  final Future<Directory> Function() _tempDirectory;

  /// The words, trimmed and non-empty. Silence reports through [onError].
  final ValueChanged<String> onTranscript;
  final ValueChanged<VoiceCaptureError> onError;

  /// A recording this long stops and transcribes on its own.
  final Duration maxDuration;

  VoiceCaptureState _state = VoiceCaptureState.idle;
  VoiceCaptureState get state => _state;
  bool get isIdle => _state == VoiceCaptureState.idle;
  bool get isRecording => _state == VoiceCaptureState.recording;

  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;

  /// The in-flight [start], awaited by [stop] and [cancel] so a release
  /// that beats the recorder's own start-up neither throws nor leaks a
  /// recording that then runs forever.
  Future<void>? _starting;
  Timer? _ticker;
  Timer? _cap;
  bool _disposed = false;

  /// Begin recording. A no-op unless idle.
  Future<void> start() {
    if (!isIdle) return _starting ?? Future.value();
    return _starting = _start();
  }

  Future<void> _start() async {
    try {
      if (!await _recorder.hasPermission()) {
        _fail(const VoiceCaptureError(
            'Microphone permission is needed to dictate.'));
        return;
      }
      final dir = await _tempDirectory();
      final path =
          '${dir.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(path);
    } catch (_) {
      _fail(const VoiceCaptureError("Couldn't start recording."));
      return;
    }
    if (_disposed) {
      await _recorder.cancel();
      return;
    }
    _elapsed = Duration.zero;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      notifyListeners();
    });
    _cap = Timer(maxDuration, stop);
    _set(VoiceCaptureState.recording);
  }

  /// Stop, transcribe, deliver. A no-op unless recording (after any
  /// in-flight [start] has settled).
  Future<void> stop() async {
    await _starting;
    if (!isRecording) return;
    _stopTimers();
    _set(VoiceCaptureState.transcribing);
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = null;
    }
    if (path == null) {
      _fail(const VoiceCaptureError("Couldn't hear anything — try again."));
      return;
    }
    try {
      final text = (await _transcribe(path)).trim();
      if (_disposed) return;
      if (text.isEmpty) {
        _fail(const VoiceCaptureError("Couldn't hear anything — try again."));
      } else {
        _set(VoiceCaptureState.idle);
        onTranscript(text);
      }
    } catch (e) {
      _fail(_describe(e));
    } finally {
      unawaited(_discard(path));
    }
  }

  /// Throw the recording away. A no-op unless recording (after any
  /// in-flight [start] has settled).
  Future<void> cancel() async {
    await _starting;
    if (!isRecording) return;
    _stopTimers();
    try {
      await _recorder.cancel();
    } catch (_) {}
    _set(VoiceCaptureState.idle);
  }

  void _fail(VoiceCaptureError error) {
    _stopTimers();
    _set(VoiceCaptureState.idle);
    if (!_disposed) onError(error);
  }

  void _set(VoiceCaptureState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  void _stopTimers() {
    _ticker?.cancel();
    _ticker = null;
    _cap?.cancel();
    _cap = null;
  }

  static Future<void> _discard(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// The server's own words for a failed transcribe — the 412 "No default
  /// STT worker configured" hint, or a 422 provider error — else a generic
  /// line.
  static VoiceCaptureError _describe(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      final server = data is Map && data['error'] is String
          ? data['error'] as String
          : null;
      if (e.response?.statusCode == 412) {
        return VoiceCaptureError(
          server ?? 'Your brain has no speech-to-text worker set up.',
          sttUnavailable: true,
        );
      }
      if (server != null) return VoiceCaptureError(server);
    }
    return const VoiceCaptureError("Couldn't transcribe the recording.");
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimers();
    if (isRecording) unawaited(_recorder.cancel().catchError((_) {}));
    unawaited(_recorder.dispose().catchError((_) {}));
    super.dispose();
  }
}
