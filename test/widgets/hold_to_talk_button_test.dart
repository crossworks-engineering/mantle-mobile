// HoldToTalkButton: hold starts, release transcribes into onTranscript,
// sliding away discards, a tap toggles for anyone who cannot hold, the
// screen-reader name follows the state, and a 412 hides the mic for the
// session.

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/features/voice/voice_capture.dart';
import 'package:jackdaw/theme/mantle_theme.dart';
import 'package:jackdaw/widgets/hold_to_talk_button.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../helpers/fake_voice_recorder.dart';

class _Rig {
  _Rig({this.throws});

  /// What a transcribe answers unless [throws] is set.
  final Object? throws;
  final recorder = FakeVoiceRecorder();
  final transcripts = <String>[];
  final errors = <String>[];
  late final ProviderContainer container = ProviderContainer(overrides: [
    voiceRecorderFactoryProvider.overrideWithValue(() => recorder),
    voiceTranscriberProvider.overrideWithValue((_) async {
      if (throws != null) throw throws!;
      return 'hello world';
    }),
  ]);

  Future<void> pump(WidgetTester tester, {bool enabled = true}) async {
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ShadApp(
          theme: MantleTheme.light(MantleTheme.defaultId),
          home: Center(
            child: HoldToTalkButton(
              enabled: enabled,
              onTranscript: transcripts.add,
              onError: errors.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// Press and keep pressing past the long-press threshold.
Future<TestGesture> _hold(WidgetTester tester) async {
  final g = await tester.startGesture(
    tester.getCenter(find.byType(HoldToTalkButton)),
  );
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await tester.pump();
  return g;
}

void main() {
  setUpAll(installFakeTempDirectory);

  testWidgets('idle: a 44pt mic named "Hold to dictate"', (tester) async {
    final rig = _Rig();
    await rig.pump(tester);
    expect(find.byIcon(LucideIcons.mic), findsOneWidget);
    expect(find.bySemanticsLabel('Hold to dictate'), findsOneWidget);
    final size = tester.getSize(find.byType(HoldToTalkButton));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('hold records (dot + timer, renamed), release delivers the words',
      (tester) async {
    final rig = _Rig();
    await rig.pump(tester);

    final g = await _hold(tester);
    expect(rig.recorder.starts, 1);
    expect(find.bySemanticsLabel('Stop dictating'), findsOneWidget);
    expect(find.byIcon(LucideIcons.mic), findsNothing);
    expect(find.text('0:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('0:03'), findsOneWidget);

    await g.up();
    await tester.pumpAndSettle();
    expect(rig.recorder.stops, 1);
    expect(rig.transcripts, ['hello world']);
    expect(rig.errors, isEmpty);
    expect(find.bySemanticsLabel('Hold to dictate'), findsOneWidget);
  });

  testWidgets('sliding up while holding discards the recording',
      (tester) async {
    final rig = _Rig();
    await rig.pump(tester);

    final g = await _hold(tester);
    await g.moveBy(const Offset(0, -20));
    await tester.pump();
    expect(rig.recorder.cancels, 0);
    await g.moveBy(const Offset(0, -(kHoldToTalkCancelDistance + 10)));
    await tester.pump();
    expect(rig.recorder.cancels, 1);

    await g.up();
    await tester.pumpAndSettle();
    expect(rig.recorder.stops, 0);
    expect(rig.transcripts, isEmpty);
  });

  testWidgets('a tap starts, a second tap stops (the no-hold fallback)',
      (tester) async {
    final rig = _Rig();
    await rig.pump(tester);

    await tester.tap(find.byType(HoldToTalkButton));
    await tester.pump();
    expect(rig.recorder.starts, 1);
    expect(find.bySemanticsLabel('Stop dictating'), findsOneWidget);

    await tester.tap(find.byType(HoldToTalkButton));
    await tester.pumpAndSettle();
    expect(rig.recorder.stops, 1);
    expect(rig.transcripts, ['hello world']);
  });

  testWidgets('disabled: nothing starts', (tester) async {
    final rig = _Rig();
    await rig.pump(tester, enabled: false);
    final g = await _hold(tester);
    await g.up();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(HoldToTalkButton));
    await tester.pumpAndSettle();
    expect(rig.recorder.starts, 0);
  });

  testWidgets('a failure goes to onError and the mic is back', (tester) async {
    final rig = _Rig(throws: StateError('boom'));
    await rig.pump(tester);
    final g = await _hold(tester);
    await g.up();
    await tester.pumpAndSettle();
    expect(rig.errors, ["Couldn't transcribe the recording."]);
    expect(find.bySemanticsLabel('Hold to dictate'), findsOneWidget);
  });

  testWidgets('a 412 shows the hint once and hides the mic for the session',
      (tester) async {
    final rig = _Rig(
      throws: DioException(
        requestOptions: RequestOptions(),
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 412,
          data: {'error': 'No default STT worker configured'},
        ),
      ),
    );
    await rig.pump(tester);
    final g = await _hold(tester);
    await g.up();
    await tester.pumpAndSettle();
    expect(rig.errors, ['No default STT worker configured']);
    expect(rig.container.read(sttAvailabilityProvider), isFalse);
    expect(find.byIcon(LucideIcons.mic), findsNothing);
    expect(find.bySemanticsLabel('Hold to dictate'), findsNothing);
  });
}
