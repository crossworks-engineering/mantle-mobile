// SSE line parsing + event model for the live chat stream.

import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/chat/conversation_stream.dart';

void main() {
  group('parseSseLine', () {
    test('parses a well-formed data line into an event', () {
      final e = parseSseLine('data: {"agentSlug":"saskia","direction":"outbound"}');
      expect(e, isNotNull);
      expect(e!.agentSlug, 'saskia');
      expect(e.direction, 'outbound');
      expect(e.fromUser, isFalse);
    });

    test('tolerates no space after "data:"', () {
      final e = parseSseLine('data:{"agentSlug":"remy","direction":"inbound"}');
      expect(e, isNotNull);
      expect(e!.agentSlug, 'remy');
      expect(e.fromUser, isTrue);
    });

    test('ignores SSE comments (heartbeat / connected)', () {
      expect(parseSseLine(': ping'), isNull);
      expect(parseSseLine(': connected'), isNull);
    });

    test('ignores blank and non-data lines', () {
      expect(parseSseLine(''), isNull);
      expect(parseSseLine('event: message'), isNull);
      expect(parseSseLine('data:'), isNull);
      expect(parseSseLine('data:   '), isNull);
    });

    test('returns null for malformed JSON', () {
      expect(parseSseLine('data: {not json'), isNull);
    });

    test('returns null when agentSlug is missing or empty', () {
      expect(parseSseLine('data: {"direction":"outbound"}'), isNull);
      expect(parseSseLine('data: {"agentSlug":"","direction":"outbound"}'), isNull);
    });

    test('defaults direction to empty string when absent', () {
      final e = parseSseLine('data: {"agentSlug":"saskia"}');
      expect(e, isNotNull);
      expect(e!.direction, '');
      expect(e.fromUser, isFalse);
    });
  });

  group('ConversationEvent.tryParse', () {
    test('inbound is fromUser', () {
      final e = ConversationEvent.tryParse({'agentSlug': 'x', 'direction': 'inbound'});
      expect(e, isNotNull);
      expect(e!.fromUser, isTrue);
    });

    test('rejects a non-string slug', () {
      expect(ConversationEvent.tryParse({'agentSlug': 42, 'direction': 'inbound'}), isNull);
    });
  });
}
