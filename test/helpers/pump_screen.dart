// Pumps one screen the way the app hosts it: a provider scope (the caller's
// container, so overrides are typed where they are written), MantleColors
// above ShadApp (screens read the chart ramp and status colours from it),
// and ShadApp with the Jackdaw theme so every ShadTheme.of(context) resolves.
// `home:` gives the screen a Navigator, so sheets and confirms can open.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/theme/mantle_theme.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  required ProviderContainer container,
}) async {
  addTearDown(container.dispose);
  // A phone's width and a tall page, so a lazy list builds every row and a
  // finder below the fold still finds it.
  tester.view.physicalSize = const Size(430, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MantleColors(
        def: MantleTheme.defFor(MantleTheme.defaultId),
        child: ShadApp(
          theme: MantleTheme.light(MantleTheme.defaultId),
          home: screen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
