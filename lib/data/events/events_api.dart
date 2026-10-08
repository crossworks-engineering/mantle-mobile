import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import 'events_models.dart';

part 'events_api.g.dart';

/// Mantle Events over HTTP: `GET/POST /api/events`, `GET/PATCH/DELETE
/// /api/events/{id}`. All owner-gated (mobile bearer works).
class EventsApi {
  EventsApi(this._dio);

  final Dio _dio;

  /// `GET /api/events?window=…&page=…` — one page (50) plus the total.
  /// `upcoming` (default) = startsAt >= now, soonest first; `past` = newest
  /// first; `all` = everything ascending.
  Future<EventsPage> list({String window = 'upcoming', int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/events',
      queryParameters: {'window': window, 'page': page},
    );
    final data = res.data ?? const {};
    final rows = ((data['events'] as List?) ?? const [])
        .map((e) => EventRow.fromJson(e as Map<String, dynamic>))
        .toList();
    return EventsPage(
      events: rows,
      total: (data['total'] as num?)?.toInt() ?? rows.length,
    );
  }

  /// `GET /api/events/{id}`: one event. A 404 (deleted, or another login's)
  /// throws like any failure; callers tell the two apart by status.
  Future<EventRow> get(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/events/$id');
    return EventRow.fromJson(
      (res.data?['event'] as Map).cast<String, dynamic>(),
    );
  }

  /// `POST /api/events` — create (201 → the saved row). `startsAt` is an
  /// absolute instant; the optional reminder lead mirrors the server worker's
  /// ping and this client's local alarm.
  Future<EventRow> create({
    required String title,
    required DateTime startsAt,
    DateTime? endsAt,
    String? location,
    int remindMinutesBefore = 0,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/events',
      data: {
        'title': title,
        'startsAt': startsAt.toUtc().toIso8601String(),
        if (endsAt != null) 'endsAt': endsAt.toUtc().toIso8601String(),
        if (location != null && location.isNotEmpty) 'location': location,
        if (remindMinutesBefore > 0)
          'remindMinutesBefore': remindMinutesBefore,
      },
    );
    return EventRow.fromJson(
      (res.data?['event'] as Map).cast<String, dynamic>(),
    );
  }

  /// `PATCH /api/events/{id}` — edit what the phone's sheet shows. Only the
  /// arguments given are sent; `clearLocation` sends `location: null`.
  /// Returns the updated row.
  Future<EventRow> update(
    String id, {
    String? title,
    DateTime? startsAt,
    String? location,
    bool clearLocation = false,
    int? remindMinutesBefore,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/api/events/$id',
      data: {
        'title': ?title,
        if (startsAt != null) 'startsAt': startsAt.toUtc().toIso8601String(),
        if (clearLocation) 'location': null else 'location': ?location,
        'remindMinutesBefore': ?remindMinutesBefore,
      },
    );
    return EventRow.fromJson(
      (res.data?['event'] as Map).cast<String, dynamic>(),
    );
  }

  /// `PATCH /api/events/{id}` with a full replacement `tags` list — how this
  /// client persists the [kEventDoneTag] "done" marker (the server has no
  /// status field). Returns the updated row.
  Future<EventRow> setTags(String id, List<String> tags) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/api/events/$id',
      data: {'tags': tags},
    );
    return EventRow.fromJson(
      (res.data?['event'] as Map).cast<String, dynamic>(),
    );
  }

  /// `DELETE /api/events/{id}`.
  Future<void> delete(String id) async {
    await _dio.delete<Map<String, dynamic>>('/api/events/$id');
  }
}

@Riverpod(keepAlive: true)
EventsApi eventsApi(Ref ref) => EventsApi(ref.watch(dioProvider));
