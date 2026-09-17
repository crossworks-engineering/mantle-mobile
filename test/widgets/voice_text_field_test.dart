// VoiceTextField: a plain-height input with the mic inside its right edge;
// dictation lands at the caret with the right spacing and never submits; a
// failure shows under the field (or goes to the screen's slot); no STT
// worker → a plain input.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/features/voice/voice_capture.dart';
import 'package:jackdaw/theme/mantle_theme.dart';
import 'package:jackdaw/widgets/hold_to_talk_button.dart';
import 'package:jackdaw/widgets/voice_text_field.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../helpers/fake_voice_recorder.dart';

void main() {
  setUpAll(installFakeTempDirectory);

  group('insertTranscript', () {
    TextEditingController c(String text, [int? caret]) {
      final ctl = TextEditingController(text: text);
      if (caret != null) ctl.selection = TextSelection.collapsed(offset: caret);
      addTearDown(ctl.dispose);
      return ctl;
    }

    test('an empty field takes the words as they are', () {
      final ctl = c('');
      insertTranscript(ctl, '  buy milk ');
      expect(ctl.text, 'buy milk');
      expect(ctl.selection.baseOffset, 8);
    });

    test('appends with a space when the field is not focused (no caret)', () {
      final ctl = c('call mum');
      insertTranscript(ctl, 'then buy milk');
      expect(ctl.text, 'call mum then buy milk');
      expect(ctl.selection.baseOffset, ctl.text.length);
    });

    test('inserts at the caret, spacing both sides', () {
      final ctl = c('call mum tonight', 8);
      insertTranscript(ctl, 'and dad');
      expect(ctl.text, 'call mum and dad tonight');
      expect(ctl.selection.baseOffset, 'call mum and dad'.length);
    });

    test('no doubled spaces beside existing whitespace or a newline', () {
      final ctl = c('first line\n', 11);
      insertTranscript(ctl, 'second');
      expect(ctl.text, 'first line\nsecond');
      final mid = c('a  b', 2);
      insertTranscript(mid, 'x');
      expect(mid.text, 'a x b');
    });

    test('replaces a selection', () {
      final ctl = c('call mum tonight');
      ctl.selection = const TextSelection(baseOffset: 5, extentOffset: 8);
      insertTranscript(ctl, 'dad');
      expect(ctl.text, 'call dad tonight');
    });

    test('blank words change nothing', () {
      final ctl = c('keep', 4);
      insertTranscript(ctl, '   ');
      expect(ctl.text, 'keep');
    });
  });

  group('widget', () {
    late FakeVoiceRecorder recorder;
    late ProviderContainer container;
    late TextEditingController controller;
    final errors = <String>[];

    Future<void> pump(
      WidgetTester tester, {
      String text = '',
      ValueChanged<String>? onError,
      int? minLines,
      int? maxLines = 1,
      String transcript = 'hello',
      bool sttDown = false,
    }) async {
      recorder = FakeVoiceRecorder();
      container = ProviderContainer(overrides: [
        voiceRecorderFactoryProvider.overrideWithValue(() => recorder),
        voiceTranscriberProvider.overrideWithValue((_) async => transcript),
      ]);
      addTearDown(container.dispose);
      if (sttDown) container.read(sttAvailabilityProvider.notifier).markUnavailable();
      controller = TextEditingController(text: text);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ShadApp(
            theme: MantleTheme.light(MantleTheme.defaultId),
            home: Center(
              child: SizedBox(
                width: 320,
                child: VoiceTextField(
                  controller: controller,
                  placeholder: const Text('Add a task…'),
                  minLines: minLines,
                  maxLines: maxLines,
                  onError: onError,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the mic sits in the field and the field stays 39pt',
        (tester) async {
      await pump(tester);
      expect(find.bySemanticsLabel('Hold to dictate'), findsOneWidget);
      expect(
        tester.getSize(find.byType(ShadInput)).height,
        lessThanOrEqualTo(40),
      );
      final mic = tester.getSize(find.byType(HoldToTalkButton));
      expect(mic.width, greaterThanOrEqualTo(44));
      expect(mic.height, greaterThanOrEqualTo(36));
    });

    testWidgets('a growing field keeps its mic and its height rule',
        (tester) async {
      await pump(tester, minLines: 1, maxLines: 4);
      expect(find.bySemanticsLabel('Hold to dictate'), findsOneWidget);
      expect(
        tester.getSize(find.byType(ShadInput)).height,
        lessThanOrEqualTo(40),
      );
    });

    testWidgets('a dictation lands at the caret; a second one extends it',
        (tester) async {
      await pump(tester, text: 'call mum', transcript: 'and dad');
      controller.selection = const TextSelection.collapsed(offset: 4);
      // Tap-toggle (the fallback) so the test needs no long-press timing.
      await tester.tap(find.byType(HoldToTalkButton));
      await tester.pump();
      await tester.tap(find.byType(HoldToTalkButton));
      await tester.pumpAndSettle();
      expect(controller.text, 'call and dad mum');
      // A second dictation extends rather than replaces.
      await tester.tap(find.byType(HoldToTalkButton));
      await tester.pump();
      await tester.tap(find.byType(HoldToTalkButton));
      await tester.pumpAndSettle();
      expect(controller.text, 'call and dad and dad mum');
    });

    testWidgets('a failure shows under the field', (tester) async {
      await pump(tester, transcript: '');
      await tester.tap(find.byType(HoldToTalkButton));
      await tester.pump();
      await tester.tap(find.byType(HoldToTalkButton));
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't hear anything"), findsOneWidget);
    });

    testWidgets("a failure goes to the screen's own slot when it has one",
        (tester) async {
      errors.clear();
      await pump(tester, transcript: '', onError: errors.add);
      await tester.tap(find.byType(HoldToTalkButton));
      await tester.pump();
      await tester.tap(find.byType(HoldToTalkButton));
      await tester.pumpAndSettle();
      expect(errors.single, contains("Couldn't hear anything"));
      expect(find.textContaining("Couldn't hear anything"), findsNothing);
    });

    testWidgets('no STT worker → a plain input, no mic', (tester) async {
      await pump(tester, sttDown: true);
      expect(find.byType(HoldToTalkButton), findsNothing);
      expect(find.byType(ShadInput), findsOneWidget);
      expect(
        tester.getSize(find.byType(ShadInput)).height,
        lessThanOrEqualTo(40),
      );
    });
  });
}
