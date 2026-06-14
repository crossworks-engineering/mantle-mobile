import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_lifecycle.g.dart';

/// Current app lifecycle state, fed by the root widget's `WidgetsBindingObserver`
/// (see `main.dart`). Providers that hold a live connection — the chat SSE
/// stream — watch this so they pause while the app is backgrounded and
/// reconnect on resume, instead of leaving a dead socket open.
@Riverpod(keepAlive: true)
class AppLifecycle extends _$AppLifecycle {
  @override
  AppLifecycleState build() => AppLifecycleState.resumed;

  // ignore: use_setters_to_change_properties
  void set(AppLifecycleState value) => state = value;
}
