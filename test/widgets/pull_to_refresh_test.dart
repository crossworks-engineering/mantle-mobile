// PullToRefreshList: a refresh that fails says so where the pull was, not
// "Up to date" (L8).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/widgets/pull_to_refresh.dart';

import '../helpers/pump_screen.dart';

void main() {
  Future<void> pull(WidgetTester tester) async {
    final gesture = await tester.startGesture(const Offset(200, 200));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(0, 15));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Widget list(Future<void> Function() onRefresh) => PullToRefreshList(
        onRefresh: onRefresh,
        itemCount: 3,
        itemBuilder: (_, i) => SizedBox(height: 40, child: Text('row $i')),
      );

  testWidgets('a failed refresh says it could not refresh', (tester) async {
    await pumpScreen(
      tester,
      list(() async => throw Exception('offline')),
      container: ProviderContainer(),
    );
    await pull(tester);

    expect(find.text("Couldn't refresh. Pull to try again."), findsOneWidget);
    expect(find.text('Up to date'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
  });

  testWidgets('a refresh that worked says it is up to date', (tester) async {
    await pumpScreen(
      tester,
      list(() async {}),
      container: ProviderContainer(),
    );
    await pull(tester);

    expect(find.text('Up to date'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
