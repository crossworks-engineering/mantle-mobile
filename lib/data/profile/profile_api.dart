import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';

part 'profile_api.g.dart';

/// Talks to Mantle's `/api/profile/*` endpoints over the authed [Dio].
class ProfileApi {
  ProfileApi(this._dio);

  final Dio _dio;

  /// `GET /api/profile/reminder-channel` → where event reminders are delivered:
  /// 'telegram' (a bot DM) or 'mobile' (a push to this app). Server defaults to
  /// 'telegram' when unset.
  Future<String> getReminderChannel() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/profile/reminder-channel');
    return (res.data?['reminderChannel'] as String?) ?? 'telegram';
  }

  /// `PUT /api/profile/reminder-channel` — set the reminder destination. Returns
  /// the stored value.
  Future<String> setReminderChannel(String channel) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/api/profile/reminder-channel',
      data: {'reminderChannel': channel},
    );
    return (res.data?['reminderChannel'] as String?) ?? channel;
  }
}

@Riverpod(keepAlive: true)
ProfileApi profileApi(Ref ref) => ProfileApi(ref.watch(dioProvider));
