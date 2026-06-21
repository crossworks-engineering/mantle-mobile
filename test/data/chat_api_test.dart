// ChatApi parsing, with a mocked Dio.

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantle_companion/data/chat/chat_api.dart';
import 'package:mantle_companion/data/chat/chat_attachment.dart';
import 'package:mantle_companion/data/chat/chat_message.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDio extends Mock implements Dio {}

/// Routes `getTemporaryDirectory()` at the system temp dir so artifact bytes
/// can be written to disk under `flutter test` (no real plugin channel).
class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
}

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

  test('turnStage returns the label, and null when empty/absent', () async {
    when(() => dio.get<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => _resp({'label': 'Thinking…'}));
    expect(await api.turnStage(), 'Thinking…');

    when(() => dio.get<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => _resp({'label': null}));
    expect(await api.turnStage(), isNull);

    when(() => dio.get<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => _resp(<String, dynamic>{}));
    expect(await api.turnStage(), isNull);
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

  test('fetchHistory parses image attachments with a node id', () async {
    when(() => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer(
      (_) async => _resp({
        'messages': [
          {
            'id': '1',
            'direction': 'inbound',
            'text': 'look at this',
            'createdAt': '2026-06-13T10:00:00.000Z',
            'attachments': [
              {
                'kind': 'image',
                'mime': 'image/jpeg',
                'caption': 'photo.jpg',
                'nodeId': 'node-1',
              },
              {'kind': 'voice', 'caption': 'Voice note'},
              {'kind': 'mystery'}, // unknown kind → dropped
            ],
          },
        ],
      }),
    );

    final messages = await api.fetchHistory();

    expect(messages.single.attachments, hasLength(2));
    final image = messages.single.attachments.first;
    expect(image.kind, AttachmentKind.image);
    expect(image.isImage, isTrue);
    expect(image.nodeId, 'node-1');
    expect(messages.single.attachments[1].kind, AttachmentKind.voice);
  });

  test('sendTurn posts multipart and keeps the reply when an attachment rides',
      () async {
    final tmp = await File(
      '${Directory.systemTemp.path}/chat_api_test_${DateTime.now().microsecondsSinceEpoch}.txt',
    ).create();
    await tmp.writeAsString('hello world');
    addTearDown(() => tmp.delete());

    when(() => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenAnswer(
      (_) async => _resp({
        'inbound': {
          'id': 'i1',
          'text': 'see attached',
          'createdAt': '2026-06-13T10:00:00.000Z',
        },
        'outbound': {
          'id': 'o1',
          'text': 'got it',
          'createdAt': '2026-06-13T10:00:02.000Z',
        },
      }),
    );

    final result = await api.sendTurn(
      'see attached',
      attachment: OutgoingAttachment(
        path: tmp.path,
        filename: 'notes.txt',
        mime: 'text/plain',
      ),
    );

    expect(result.inbound.text, 'see attached');
    expect(result.outbound.text, 'got it');
    final captured = verify(() => dio.post<Map<String, dynamic>>(
          '/api/assistant/turn',
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        )).captured.single;
    expect(captured, isA<FormData>());
    // A document goes under the 'file' field (images would use 'image').
    expect((captured as FormData).files.single.key, 'file');
  });

  test('transcribe returns the trimmed transcript', () async {
    final tmp = await File(
      '${Directory.systemTemp.path}/chat_api_voice_${DateTime.now().microsecondsSinceEpoch}.m4a',
    ).create();
    await tmp.writeAsBytes([0, 1, 2, 3]);
    addTearDown(() => tmp.delete());

    when(() => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => _resp({'text': '  hello there  '}));

    final text = await api.transcribe(tmp.path);
    expect(text, 'hello there');
  });

  test('sendTurn writes an outbound audio artifact to a playable file',
      () async {
    PathProviderPlatform.instance = _FakePathProvider();
    final audioBytes = [1, 2, 3, 4, 5];

    when(() => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenAnswer(
      (_) async => _resp({
        'inbound': {
          'id': 'i1',
          'text': 'read that aloud',
          'createdAt': '2026-06-13T10:00:00.000Z',
        },
        'outbound': {
          'id': 'o1',
          'text': 'Here you go 🔊',
          'createdAt': '2026-06-13T10:00:02.000Z',
        },
        'artifacts': [
          {
            'kind': 'audio',
            'mimeType': 'audio/mpeg',
            'base64': base64Encode(audioBytes),
            'caption': 'Here you go',
            'producedBy': 'send-voice-reply',
          },
        ],
      }),
    );

    final result = await api.sendTurn('read that aloud');

    expect(result.outbound.attachments, hasLength(1));
    final audio = result.outbound.attachments.single;
    expect(audio.kind, AttachmentKind.audio);
    expect(audio.localPath, isNotNull);
    final file = File(audio.localPath!);
    addTearDown(() => file.delete());
    expect(file.existsSync(), isTrue);
    expect(file.path, endsWith('.mp3'));
    expect(await file.readAsBytes(), audioBytes);
  });
}
