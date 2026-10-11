import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/lifecycle/app_lifecycle.dart';
import '../../data/events/event_alarms.dart';
import '../../data/events/events_api.dart';
import '../../data/events/events_models.dart';
import '../auth/login_access_controller.dart';
import '../auth/session_controller.dart';

import '../dashboard/up_next_controller.dart';

part 'events_controller.g.dart';

/// Owns the upcoming-events list. Every successful load or mutation also
/// re-syncs the device's LOCAL alarms ([EventAlarms.sync]) so what's on the
/// screen and what will ring are never out of step.
///
/// "Done" is the [kEventDoneTag] tag (the server has no event status field):
/// marking done persists the tag via PATCH, keeps the row's history, and
/// cancels its alarms on the next sync.
@riverpod
class EventsController extends _$EventsController {
  @override
  Future<List<EventRow>> build() {
    // Rebuilt with the client: another login, or another brain.
    ref.watch(eventsApiProvider);
    return _load();
  }

  /// The screen's window: the last 7 days (so a just-finished event is still
  /// there to mark done — `window=upcoming` alone drops an event the moment
  /// it starts) followed by everything upcoming. Fetched as the server's two
  /// windows in parallel and merged in start order.
  Future<List<EventRow>> _load() async {
    final api = ref.read(eventsApiProvider);
    final results = await Future.wait([
      api.list(window: 'past'), // newest past first — page 1 = most recent
      api.list(), // upcoming, soonest first
    ]);
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 7));
    final events = [
      ...results[0].events.where((e) => e.startsAt.isAfter(cutoff)),
      ...results[1].events,
    ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    unawaited(EventAlarms.sync(events));
    return events;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final next = await AsyncValue.guard(_load);
    if (ref.mounted) state = next;
  }

  /// Create an event and insert it in start order. Throws on failure so the
  /// add sheet can surface it.
  Future<void> add({
    required String title,
    required DateTime startsAt,
    String? location,
    int remindMinutesBefore = 0,
  }) async {
    final row = await ref.read(eventsApiProvider).create(
          title: title,
          startsAt: startsAt,
          location: location,
          remindMinutesBefore: remindMinutesBefore,
        );
    if (!ref.mounted) return;
    refreshUpNextIfShown(ref);
    final current = state.value;
    if (current != null) {
      final merged = [...current, row]
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      state = AsyncData(merged);
      unawaited(EventAlarms.sync(merged));
    }
  }

  /// Edit an event from the sheet. Server first (the sheet shows a failure),
  /// then the row is swapped in, the list re-sorted (the time may have
  /// moved) and the alarms re-armed. Throws on failure.
  Future<void> edit(
    String id, {
    String? title,
    DateTime? startsAt,
    String? location,
    bool clearLocation = false,
    int? remindMinutesBefore,
  }) async {
    final updated = await ref.read(eventsApiProvider).update(
          id,
          title: title,
          startsAt: startsAt,
          location: location,
          clearLocation: clearLocation,
          remindMinutesBefore: remindMinutesBefore,
        );
    if (!ref.mounted) return;
    refreshUpNextIfShown(ref);
    final current = state.value;
    if (current != null) {
      final next = [
        for (final e in current)
          if (e.id == id) updated else e,
      ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      state = AsyncData(next);
      unawaited(EventAlarms.sync(next));
    }
  }

  /// Flip the done tag, optimistically; the server row keeps every other tag.
  Future<void> setDone(String id, {required bool done}) async {
    final current = state.value;
    if (current == null) return;
    EventRow? row;
    for (final e in current) {
      if (e.id == id) {
        row = e;
        break;
      }
    }
    if (row == null) return;
    final tags = done
        ? [...row.tags, kEventDoneTag]
        : [...row.tags.where((t) => t != kEventDoneTag)];
    try {
      final updated = await ref.read(eventsApiProvider).setTags(id, tags);
      if (!ref.mounted) return;
      refreshUpNextIfShown(ref);
      final next = [
        for (final e in current)
          if (e.id == id) updated else e,
      ];
      state = AsyncData(next);
      unawaited(EventAlarms.sync(next));
    } catch (_) {
      await _reloadSilently();
    }
  }

  /// Delete an event (long-press action), optimistically.
  Future<void> delete(String id) async {
    final current = state.value;
    if (current != null) {
      final next = [
        for (final e in current)
          if (e.id != id) e,
      ];
      state = AsyncData(next);
      unawaited(EventAlarms.sync(next));
    }
    try {
      await ref.read(eventsApiProvider).delete(id);
      if (ref.mounted) refreshUpNextIfShown(ref);
    } catch (_) {
      await _reloadSilently();
    }
  }

  Future<void> _reloadSilently() async {
    try {
      final rows = await _load();
      if (ref.mounted) state = AsyncData(rows);
    } catch (_) {
      /* keep current; pull-to-refresh reconciles */
    }
  }
}

/// Keeps device alarms fresh WITHOUT the events screen ever being opened:
/// on login and on every foreground resume it pulls the upcoming window and
/// reconciles the local schedule (an event added from the web or by the
/// assistant still rings on the phone). keepAlive + watched once from the app
/// root, like the theme scheduler — nothing reads its (void) value.
@Riverpod(keepAlive: true)
class EventAlarmSync extends _$EventAlarmSync {
  @override
  void build() {
    final session = ref.watch(sessionControllerProvider).value;
    final lifecycle = ref.watch(appLifecycleProvider);
    // A switch cancels every alarm (the session wipe) and the new login's
    // are armed here. A switch between two logins on one brain changes
    // neither value above, only the client, so the client is watched too.
    ref.watch(eventsApiProvider);
    // Events are the Admin workspace's: a member's routes refuse them.
    final access = ref.watch(currentAccessProvider);
    if (session != AuthStatus.loggedIn) return;
    if (lifecycle != AppLifecycleState.resumed) return;
    if (access == null || !access.ownerContent) return;
    unawaited(_syncOnce());
  }

  Future<void> _syncOnce() async {
    try {
      final events = (await ref.read(eventsApiProvider).list()).events;
      await EventAlarms.sync(events);
    } catch (_) {
      /* offline / server down — existing schedules stay armed */
    }
  }
}
