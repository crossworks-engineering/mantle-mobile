// VoiceCapture: the one dictation state machine. Permission → record → stop
// → transcribe → the words; cancel discards; the cap stops a forgotten
// recording; a release that beats the recorder's start-up is harmless; a
// 412 is flagged so the session can hide the mic.

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/features/voice/voice_capture.dart';

import '../helpers/fake_voice_recorder.dart';

DioException _http(int status, [String? error]) => DioException(
      requestOptions: RequestOptions(path: '/api/assistant/transcribe'),
      response: Response(
        requestOptions: RequestOptions(path: '/api/assistant/transcribe'),
        statusCode: status,
        data: error == null ? null : {'error': error},
      ),
    );

class _Harness {
  _Harness({
    FakeVoiceRecorder? recorder,
    Future<String> Function(String)? transcribe,
    Duration maxDuration = const Duration(seconds: 60),
  })  : recorder = recorder ?? FakeVoiceRecorder(),
        transcribe = transcribe ?? ((_) async => '  hello there  ') {
    capture = VoiceCapture(
      recorder: this.recorder,
      transcribe: (p) => this.transcribe(p),
      onTranscript: transcripts.add,
      onError: errors.add,
      maxDuration: maxDuration,
      tempDirectory: () async => Directory.systemTemp,
    );
    capture.addListener(() => states.add(capture.state));
  }

  final FakeVoiceRecorder recorder;
  final Future<String> Function(String) transcribe;
  late final VoiceCapture capture;
  final transcripts = <String>[];
  final errors = <VoiceCaptureError>[];
  final states = <VoiceCaptureState>[];
}

void main() {
  testWidgets('start → recording (with a ticking clock) → stop → the words',
      (tester) async {
    final h = _Harness();
    await h.capture.start();
    expect(h.capture.state, VoiceCaptureState.recording);
    expect(h.recorder.starts, 1);
    expect(h.recorder.lastPath, endsWith('.m4a'));
    expect(h.capture.elapsed, Duration.zero);

    await tester.pump(const Duration(seconds: 2));
    expect(h.capture.elapsed, const Duration(seconds: 2));

    await h.capture.stop();
    expect(h.recorder.stops, 1);
    expect(h.transcripts, ['hello there']);
    expect(h.errors, isEmpty);
    expect(h.capture.state, VoiceCaptureState.idle);
    expect(
      h.states,
      containsAllInOrder([
        VoiceCaptureState.recording,
        VoiceCaptureState.transcribing,
        VoiceCaptureState.idle,
      ]),
    );
    h.capture.dispose();
  });

  testWidgets('cancel throws the recording away and transcribes nothing',
      (tester) async {
    final h = _Harness();
    await h.capture.start();
    await h.capture.cancel();
    expect(h.recorder.cancels, 1);
    expect(h.recorder.stops, 0);
    expect(h.transcripts, isEmpty);
    expect(h.capture.state, VoiceCaptureState.idle);
    // Idle: neither stop nor cancel does anything more.
    await h.capture.stop();
    await h.capture.cancel();
    expect(h.recorder.stops, 0);
    expect(h.recorder.cancels, 1);
    h.capture.dispose();
  });

  testWidgets('the cap stops a forgotten recording on its own', (tester) async {
    final h = _Harness(maxDuration: const Duration(seconds: 5));
    await h.capture.start();
    await tester.pump(const Duration(seconds: 4));
    expect(h.capture.isRecording, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(h.recorder.stops, 1);
    expect(h.transcripts, ['hello there']);
    // The release that follows is a no-op.
    await h.capture.stop();
    expect(h.recorder.stops, 1);
    h.capture.dispose();
  });

  testWidgets('a release before the recorder has started still stops it once',
      (tester) async {
    final h = _Harness();
    h.recorder.startGate = Completer<void>();
    final starting = h.capture.start();
    final stopping = h.capture.stop(); // released already
    expect(h.capture.state, VoiceCaptureState.idle);
    expect(h.recorder.stops, 0);

    h.recorder.startGate!.complete();
    await starting;
    await stopping;
    expect(h.recorder.starts, 1);
    expect(h.recorder.stops, 1);
    expect(h.transcripts, ['hello there']);
    expect(h.capture.state, VoiceCaptureState.idle);
    h.capture.dispose();
  });

  testWidgets('a second start while recording does not start twice',
      (tester) async {
    final h = _Harness();
    await h.capture.start();
    await h.capture.start();
    expect(h.recorder.starts, 1);
    h.capture.dispose();
  });

  testWidgets('no permission → an error, never recording', (tester) async {
    final h = _Harness(recorder: FakeVoiceRecorder(permitted: false));
    await h.capture.start();
    expect(h.recorder.starts, 0);
    expect(h.capture.state, VoiceCaptureState.idle);
    expect(h.errors.single.message, contains('Microphone access is off'));
    expect(h.errors.single.sttUnavailable, isFalse);
    h.capture.dispose();
  });

  testWidgets('a recorder that will not start → an error', (tester) async {
    final h = _Harness(recorder: FakeVoiceRecorder()..failStart = true);
    await h.capture.start();
    expect(h.capture.state, VoiceCaptureState.idle);
    expect(h.errors.single.message, "Couldn't start recording.");
    h.capture.dispose();
  });

  testWidgets('silence (an empty transcript, or no file) → "Couldn\'t hear"',
      (tester) async {
    final h = _Harness(transcribe: (_) async => '   ');
    await h.capture.start();
    await h.capture.stop();
    expect(h.transcripts, isEmpty);
    expect(h.errors.single.message, contains("Couldn't hear anything"));
    h.capture.dispose();

    final none = _Harness(recorder: FakeVoiceRecorder(stopPath: null));
    await none.capture.start();
    await none.capture.stop();
    expect(none.errors.single.message, contains("Couldn't hear anything"));
    none.capture.dispose();
  });

  testWidgets("412 → the server's hint, flagged sttUnavailable",
      (tester) async {
    final h = _Harness(
      transcribe: (_) => throw _http(412, 'No default STT worker configured'),
    );
    await h.capture.start();
    await h.capture.stop();
    expect(h.errors.single.message, 'No default STT worker configured');
    expect(h.errors.single.sttUnavailable, isTrue);
    expect(h.capture.state, VoiceCaptureState.idle);
    h.capture.dispose();
  });

  testWidgets("412 without a body → our own words, still flagged",
      (tester) async {
    final h = _Harness(transcribe: (_) => throw _http(412));
    await h.capture.start();
    await h.capture.stop();
    expect(h.errors.single.message, contains('speech-to-text'));
    expect(h.errors.single.sttUnavailable, isTrue);
    h.capture.dispose();
  });

  testWidgets("422 → the server's message; anything else → a generic line",
      (tester) async {
    final h = _Harness(
      transcribe: (_) => throw _http(422, 'Provider timed out'),
    );
    await h.capture.start();
    await h.capture.stop();
    expect(h.errors.single.message, 'Provider timed out');
    expect(h.errors.single.sttUnavailable, isFalse);
    h.capture.dispose();

    final other = _Harness(transcribe: (_) => throw StateError('boom'));
    await other.capture.start();
    await other.capture.stop();
    expect(other.errors.single.message, "Couldn't transcribe the recording.");
    other.capture.dispose();
  });

  testWidgets('dispose while recording cancels and releases the recorder',
      (tester) async {
    final h = _Harness();
    await h.capture.start();
    h.capture.dispose();
    await tester.pump();
    expect(h.recorder.cancels, 1);
    expect(h.recorder.disposed, isTrue);
  });
}
