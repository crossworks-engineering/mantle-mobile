// Smoke test: the app boots and renders its shadcn-themed landing screen.

import 'package:flutter_test/flutter_test.dart';

import 'package:mantle_companion/main.dart';

void main() {
  testWidgets('App boots and shows the landing screen', (tester) async {
    await tester.pumpWidget(const MantleCompanionApp());

    expect(find.text('Mantle Companion'), findsOneWidget);
    expect(find.text('Start a chat'), findsOneWidget);
  });
}
