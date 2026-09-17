// SecretInput: masked until the eye is tapped, the eye is named for screen
// readers and flips its name with the state, and the toggle never touches the
// text (a password-manager fill survives a peek).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/theme/mantle_theme.dart';
import 'package:jackdaw/widgets/secret_input.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<TextEditingController> _pump(WidgetTester tester,
    {bool enabled = true}) async {
  final controller = TextEditingController(text: 'hunter2');
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    ShadApp(
      theme: MantleTheme.light(MantleTheme.defaultId),
      home: Center(
        child: SizedBox(
          width: 320,
          child: SecretInput(
            controller: controller,
            placeholder: const Text('Password'),
            enabled: enabled,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

EditableText _editable(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText));

void main() {
  testWidgets('starts masked with a "Show password" eye', (tester) async {
    await _pump(tester);
    expect(_editable(tester).obscureText, isTrue);
    expect(find.bySemanticsLabel('Show password'), findsOneWidget);
    expect(find.bySemanticsLabel('Hide password'), findsNothing);
  });

  testWidgets('tapping the eye reveals the text and renames the eye',
      (tester) async {
    final controller = await _pump(tester);

    await tester.tap(find.bySemanticsLabel('Show password'));
    await tester.pumpAndSettle();
    expect(_editable(tester).obscureText, isFalse);
    expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
    expect(find.text('hunter2'), findsOneWidget);
    expect(controller.text, 'hunter2');

    await tester.tap(find.bySemanticsLabel('Hide password'));
    await tester.pumpAndSettle();
    expect(_editable(tester).obscureText, isTrue);
    expect(find.bySemanticsLabel('Show password'), findsOneWidget);
    expect(controller.text, 'hunter2');
  });

  testWidgets('the eye is 44pt wide, the field stays as tall as a plain '
      'input, and nothing happens while disabled', (tester) async {
    await _pump(tester, enabled: false);
    final box = tester.getSize(find.ancestor(
      of: find.byIcon(LucideIcons.eye),
      matching: find.byType(SizedBox),
    ).first);
    expect(box.width, greaterThanOrEqualTo(44));
    // A default ShadInput is 39pt; the eye must not grow the field.
    expect(tester.getSize(find.byType(ShadInput)).height, lessThanOrEqualTo(40));
    expect(box.height, greaterThanOrEqualTo(36));

    await tester.tap(find.bySemanticsLabel('Show password'));
    await tester.pumpAndSettle();
    expect(_editable(tester).obscureText, isTrue);
  });

  testWidgets('carries the password autofill hint by default', (tester) async {
    await _pump(tester);
    expect(_editable(tester).autofillHints, contains(AutofillHints.password));
  });
}
