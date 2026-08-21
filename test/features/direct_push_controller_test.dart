import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/features/settings/push/direct_push_controller.dart';

void main() {
  // FlutterForegroundTask (called inside disable()) is a method-channel plugin,
  // so the test binding must exist. The call itself fails unmocked, but
  // AsyncValue.guard absorbs that — this test is about the *lifecycle*, not the
  // platform result.
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'disable() does not throw when the provider auto-disposes mid-async '
    '(regression: iOS "Connect" hung forever — "Cannot use Ref after disposed")',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Hold the provider alive only long enough to grab the notifier — this
      // mirrors the real call site `ref.read(directPushControllerProvider
      // .notifier)`, where on iOS nothing watches this (Android-only) provider.
      final sub = container.listen(
        directPushControllerProvider.notifier,
        (_, _) {},
      );
      final notifier = sub.read();

      // Kick off disable() (now awaiting FlutterForegroundTask.stopService),
      // then drop the only keep-alive so it auto-disposes during the await.
      final future = notifier.disable();
      sub.close();

      // Before the fix the post-await `state =` threw on the disposed provider;
      // now it's guarded by `ref.mounted`, so this completes cleanly.
      await expectLater(future, completes);
    },
  );
}
