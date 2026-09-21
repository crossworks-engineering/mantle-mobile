import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// True when [bytes] are an SVG document.
///
/// Sniffed from the content, not the filename or the MIME type: a `media:`
/// image on a page arrives as bare bytes with neither, and a brain file's name
/// is whatever the owner typed. Looks for an `<svg` tag in the head of the
/// file, past an optional BOM, XML prolog, doctype and comments.
bool looksLikeSvg(Uint8List bytes) {
  if (bytes.isEmpty) return false;
  final head = utf8
      .decode(
        bytes.sublist(0, bytes.length < 2048 ? bytes.length : 2048),
        allowMalformed: true,
      )
      .toLowerCase();
  final at = head.indexOf('<svg');
  if (at < 0) return false;
  // A raster format never starts with markup; an SVG has nothing but markup
  // and whitespace before its root tag.
  final lead = head.substring(0, at).replaceFirst('﻿', '').trimLeft();
  return lead.isEmpty || lead.startsWith('<');
}

/// An image from raw bytes, whatever kind it is: SVG through `flutter_svg`,
/// everything else through the engine's decoders. `Image.memory` alone draws
/// nothing for an SVG, and the brain stores SVGs as `image/svg+xml`, so every
/// place that shows "an image file" has to handle both.
///
/// [onError] is what to show when the bytes decode as neither.
class BytesImage extends StatelessWidget {
  const BytesImage(
    this.bytes, {
    super.key,
    this.fit = BoxFit.contain,
    this.onError,
  });

  final Uint8List bytes;
  final BoxFit fit;
  final WidgetBuilder? onError;

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext c) =>
        onError?.call(c) ?? const SizedBox.shrink();
    if (looksLikeSvg(bytes)) {
      return SvgPicture.memory(
        bytes,
        fit: fit,
        errorBuilder: (c, _, _) => fallback(c),
      );
    }
    return Image.memory(
      bytes,
      fit: fit,
      errorBuilder: (c, _, _) => fallback(c),
    );
  }
}
