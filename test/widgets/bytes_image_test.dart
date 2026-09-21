import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/widgets/bytes_image.dart';

Uint8List text(String s) => Uint8List.fromList(utf8.encode(s));

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10"/></svg>';

/// A 1x1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  group('looksLikeSvg', () {
    test('a bare svg root', () => expect(looksLikeSvg(text(_svg)), isTrue));

    test('past a BOM, an XML prolog, a doctype and a comment', () {
      expect(
        looksLikeSvg(
          text(
            '﻿<?xml version="1.0" encoding="UTF-8"?>\n'
            '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "x.dtd">\n'
            '<!-- exported from a drawing app -->\n$_svg',
          ),
        ),
        isTrue,
      );
    });

    test('uppercase tag and leading whitespace', () {
      expect(looksLikeSvg(text('\n\n  <SVG viewBox="0 0 1 1"></SVG>')), isTrue);
    });

    test('a raster image is not an svg', () {
      expect(looksLikeSvg(_png), isFalse);
    });

    test('text that merely mentions an svg tag is not one', () {
      expect(looksLikeSvg(text('how to write an <svg> element')), isFalse);
    });

    test('empty bytes', () => expect(looksLikeSvg(Uint8List(0)), isFalse));
  });

  group('BytesImage', () {
    Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: child),
    );

    testWidgets('draws an svg with flutter_svg', (tester) async {
      await pump(tester, BytesImage(text(_svg)));
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('draws a raster image with the engine decoder', (tester) async {
      await pump(tester, BytesImage(_png));
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
    });
  });
}
