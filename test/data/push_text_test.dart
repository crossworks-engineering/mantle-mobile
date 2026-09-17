import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/push/push_text.dart';

void main() {
  group('pushNotificationText', () {
    test('passes a normal payload through', () {
      final t = pushNotificationText({'t': 'Morph', 'b': 'hello there'});
      expect(t.title, 'Morph');
      expect(t.body, 'hello there');
    });

    test('falls back when a field is missing', () {
      final t = pushNotificationText({});
      expect(t.title, pushDefaultTitle);
      expect(t.body, pushDefaultBody);
    });

    test('falls back when the body is blank, not only when it is missing', () {
      // A server that pushes on the reply's pending insert seals b: "".
      // Seen on the S20 Ultra against dev v0.232.191: "Morph" over nothing.
      expect(pushNotificationText({'t': 'Morph', 'b': ''}).body, pushDefaultBody);
      expect(pushNotificationText({'t': 'Morph', 'b': '  \n\t '}).body, pushDefaultBody);
      expect(pushNotificationText({'t': '', 'b': 'x'}).title, pushDefaultTitle);
    });

    test('ignores non-string fields', () {
      final t = pushNotificationText({'t': 42, 'b': null});
      expect(t.title, pushDefaultTitle);
      expect(t.body, pushDefaultBody);
    });

    test('collapses whitespace and cuts a long body with an ellipsis', () {
      expect(pushNotificationText({'b': 'a  b\n\nc'}).body, 'a b c');
      final long = List.filled(200, 'x').join();
      final body = pushNotificationText({'b': long}).body;
      expect(body.length, 140);
      expect(body.endsWith('…'), isTrue);
      expect(pushNotificationText({'b': long}, maxBody: 10).body, 'xxxxxxxxx…');
    });

    test('keeps a body exactly at the limit', () {
      final exact = List.filled(140, 'y').join();
      expect(pushNotificationText({'b': exact}).body, exact);
    });
  });
}
