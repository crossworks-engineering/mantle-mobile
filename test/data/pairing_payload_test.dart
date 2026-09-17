// PairingPayload: the one parser for the web app's sign-in QR. Only a
// version-1 `/pair` URL on an address the app would accept passes; the
// server is the URL's origin, the code comes from the fragment.

import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/auth/pairing_payload.dart';

const _code = 'Ab3-dEf_GhIjKlMnOpQrSt';

void main() {
  test('a v1 pair URL yields the origin and the code', () {
    final p = PairingPayload.parse('https://brain.example.com/pair#v=1&code=$_code');
    expect(p, isNotNull);
    expect(p!.server, 'https://brain.example.com');
    expect(p.code, _code);
  });

  test('a non-default port and a trailing slash survive; the path is dropped',
      () {
    final p = PairingPayload.parse(
      ' https://brain.example.com:8443/pair/#code=$_code&v=1 ',
    );
    expect(p!.server, 'https://brain.example.com:8443');
    expect(p.code, _code);
  });

  test('plain http is fine on a private host, refused on the internet', () {
    expect(PairingPayload.parse('http://192.168.1.20:3000/pair#v=1&code=$_code')
        ?.server, 'http://192.168.1.20:3000');
    expect(PairingPayload.parse('http://brain.example.com/pair#v=1&code=$_code'),
        isNull);
  });

  test('anything that is not ours is null', () {
    for (final raw in [
      '',
      'hello',
      'https://brain.example.com/',
      'https://brain.example.com/pair',
      'https://brain.example.com/pair#v=2&code=$_code',
      'https://brain.example.com/pair#code=$_code',
      'https://brain.example.com/pair#v=1&code=short',
      'https://brain.example.com/pair#v=1&code=has+plus+and/slash+aaaaaaaa',
      'https://brain.example.com/pair?v=1&code=$_code', // query, not fragment
      'https://brain.example.com/other#v=1&code=$_code',
      'jackdaw://pair#v=1&code=$_code',
      'https://user:pw@brain.example.com/pair#v=1&code=$_code',
      'WIFI:S:home;T:WPA;P:secret;;',
    ]) {
      expect(PairingPayload.parse(raw), isNull, reason: raw);
    }
  });
}
