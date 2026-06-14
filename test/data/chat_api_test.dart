// ChatApi parsing, with a mocked Dio.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantle_companion/data/chat/chat_api.dart';
import 'package:mantle_companion/data/chat/chat_message.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _resp(Map<String, dynamic> data) => Response(
      requestOptions: RequestOptions(path: '/'),
      statusCode: 200,
      data: data,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(Options());
  });

  late MockDio dio;
  late ChatApi api;

  setUp(() {
    dio = MockDio();
    api = ChatApi(dio);
  });

  test('fetchHistory maps direction, text and model', () async {
    when(() => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer(
      (_) async => _resp({
        'messages': [
          {
            'id': '1',
            'direction': 'inbound',
            'text': 'hi',
            'model': null,
            'createdAt': '2026-06-13T10:00:00.000Z',
          },
          {
            'id': '2',
            'direction': 'outbound',
            'text': 'hello',
            'model': 'claude-opus',
            'createdAt': '2026-06-13T10:00:01.000Z',
          },
        ],
      }),
    );

    final messages = await api.fetchHistory();

    expect(messages, hasLength(2));
    expect(messages[0].isFromUser, isTrue);
    expect(messages[1].direction, MessageDirection.outbound);
    expect(messages[1].model, 'claude-opus');
  });

  test('sendTurn returns the inbound message and the assistant reply', () async {
    when(() => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenAnswer(
      (_) async => _resp({
        'inbound': {
          'id': 'i1',
          'text': 'hey',
          'createdAt': '2026-06-13T10:00:00.000Z',
        },
        'outbound': {
          'id': 'o1',
          'text': 'yo',
          'model': 'claude-opus',
          'createdAt': '2026-06-13T10:00:02.000Z',
        },
        'reply': 'yo',
      }),
    );

    final result = await api.sendTurn('hey');

    expect(result.inbound.text, 'hey');
    expect(result.inbound.direction, MessageDirection.inbound);
    expect(result.outbound.text, 'yo');
    expect(result.outbound.model, 'claude-opus');
  });
}
