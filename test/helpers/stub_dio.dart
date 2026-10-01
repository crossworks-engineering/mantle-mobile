// A real Dio over a stub adapter: the request the client builds (path, query,
// body) is what the test sees, and the answer is a real response, so status
// handling and JSON decoding run exactly as they do against a brain.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef StubAnswer = ({int status, String body});

class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.answer);

  /// Decide the answer for one request.
  final StubAnswer Function(RequestOptions options) answer;

  /// Every request made, in order.
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final a = answer(options);
    return ResponseBody.fromBytes(
      utf8.encode(a.body),
      a.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A Dio whose every request is answered by [adapter].
Dio stubDio(StubAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://brain.test'))..httpClientAdapter = adapter;
