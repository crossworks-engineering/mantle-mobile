// SSE line parsing + the TurnEvent model for the live turn stream.

import 'package:flutter_test/flutter_test.dart';
import 'package:mantle_companion/data/chat/turn_event.dart';

void main() {
  group('parseTurnSseLine', () {
    test('parses a text-delta data line into an event', () {
      final e = parseTurnSseLine(
        'data: {"v":1,"turnId":"abc","seq":7,"round":1,"type":"text-delta","data":{"text":"Hel"}}',
      );
      expect(e, isNotNull);
      expect(e!.turnId, 'abc');
      expect(e.seq, 7);
      expect(e.round, 1);
      expect(e.isTextDelta, isTrue);
      expect(e.text, 'Hel');
    });

    test('tolerates no space after "data:"', () {
      final e = parseTurnSseLine(
        'data:{"turnId":"x","seq":0,"type":"status","data":{"label":"Thinking…"}}',
      );
      expect(e, isNotNull);
      expect(e!.isStatus, isTrue);
      expect(e.label, 'Thinking…');
    });

    test('ignores the id: cursor line, comments, and blanks', () {
      expect(parseTurnSseLine('id: 7'), isNull);
      expect(parseTurnSseLine(': connected'), isNull);
      expect(parseTurnSseLine(': ping'), isNull);
      expect(parseTurnSseLine(''), isNull);
      expect(parseTurnSseLine('event: message'), isNull);
      expect(parseTurnSseLine('data:'), isNull);
      expect(parseTurnSseLine('data:   '), isNull);
    });

    test('returns null for malformed JSON', () {
      expect(parseTurnSseLine('data: {not json'), isNull);
    });
  });

  group('TurnEvent.tryParse', () {
    test('captures turn-start ids and model', () {
      final e = TurnEvent.tryParse({
        'turnId': 't1',
        'seq': 0,
        'round': 0,
        'type': 'turn-start',
        'data': {'agentSlug': 'saskia', 'model': 'claude-opus', 'inboundId': 'i1', 'outboundId': 'o1'},
      });
      expect(e, isNotNull);
      expect(e!.isTurnStart, isTrue);
      expect(e.inboundId, 'i1');
      expect(e.outboundId, 'o1');
      expect(e.model, 'claude-opus');
    });

    test('done and error are terminal; error carries a message', () {
      final done = TurnEvent.tryParse(
        {'turnId': 't', 'seq': 9, 'type': 'done', 'data': {'status': 'complete'}},
      );
      expect(done!.isDone, isTrue);
      expect(done.isTerminal, isTrue);

      final err = TurnEvent.tryParse(
        {'turnId': 't', 'seq': 9, 'type': 'error', 'data': {'status': 'failed', 'message': 'boom'}},
      );
      expect(err!.isError, isTrue);
      expect(err.isTerminal, isTrue);
      expect(err.message, 'boom');
    });

    test('text-delta is not terminal', () {
      final e = TurnEvent.tryParse(
        {'turnId': 't', 'seq': 1, 'type': 'text-delta', 'data': {'text': 'hi'}},
      );
      expect(e!.isTerminal, isFalse);
    });

    test('defaults v/round and tolerates a missing data payload', () {
      final e = TurnEvent.tryParse({'turnId': 't', 'seq': 3, 'type': 'done'});
      expect(e, isNotNull);
      expect(e!.v, 1);
      expect(e.round, 0);
      expect(e.data, isEmpty);
    });

    test('coerces a numeric seq from a double', () {
      final e = TurnEvent.tryParse(
        {'turnId': 't', 'seq': 4.0, 'type': 'status', 'data': {'label': 'x'}},
      );
      expect(e, isNotNull);
      expect(e!.seq, 4);
    });

    test('rejects frames missing type / turnId / seq', () {
      expect(TurnEvent.tryParse({'turnId': 't', 'seq': 1}), isNull); // no type
      expect(TurnEvent.tryParse({'type': 'done', 'seq': 1}), isNull); // no turnId
      expect(TurnEvent.tryParse({'type': 'done', 'turnId': 't'}), isNull); // no seq
      expect(
        TurnEvent.tryParse({'type': '', 'turnId': 't', 'seq': 1}),
        isNull, // empty type
      );
      expect(
        TurnEvent.tryParse({'type': 'done', 'turnId': '', 'seq': 1}),
        isNull, // empty turnId
      );
      expect(
        TurnEvent.tryParse({'type': 'done', 'turnId': 't', 'seq': 'nope'}),
        isNull, // non-numeric seq
      );
    });
  });
}
