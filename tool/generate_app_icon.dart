// App-icon master generator.
//
// Takes the brand logo (a black "m" on transparent — assets/icon/source/
// mantle_logo.png) and composes the two masters flutter_launcher_icons needs:
//
//   assets/icon/app_icon.png            1024² opaque indigo, white m  (iOS + legacy Android)
//   assets/icon/app_icon_foreground.png 1024² transparent, white m    (Android adaptive foreground)
//
// It recolors the glyph white (preserving anti-aliased edges), trims the
// transparent margins, then centers it square with sensible coverage. Re-run
// after changing the source, then run `fvm dart run flutter_launcher_icons`.
//
//   fvm dart run tool/generate_app_icon.dart
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

/// Mantle Clean Slate primary (#6366F1).
const _bgR = 0x63, _bgG = 0x66, _bgB = 0xF1;

/// Glyph coverage (fraction of the canvas the logo's longest side fills).
/// iOS fills more; the adaptive foreground stays inside the ~66% safe zone.
const _iosCoverage = 0.74;
const _adaptiveCoverage = 0.56;

void main() {
  final src = File('assets/icon/source/mantle_logo.png');
  if (!src.existsSync()) {
    stderr.writeln('✗ Missing ${src.path}');
    exit(1);
  }
  final logo = img.decodePng(src.readAsBytesSync());
  if (logo == null) {
    stderr.writeln('✗ Could not decode ${src.path}');
    exit(1);
  }

  final glyph = _trim(_recolorWhite(logo));

  _write('assets/icon/app_icon.png',
      _compose(glyph, 1024, _iosCoverage, opaque: true));
  _write('assets/icon/app_icon_foreground.png',
      _compose(glyph, 1024, _adaptiveCoverage, opaque: false));

  stdout.writeln('✅ wrote assets/icon/app_icon.png + app_icon_foreground.png');
}

/// Set every non-transparent pixel to white, keeping its alpha (so the rounded,
/// anti-aliased edges stay smooth). Mutates and returns [src].
img.Image _recolorWhite(img.Image src) {
  for (final p in src) {
    if (p.a > 0) p.setRgb(255, 255, 255);
  }
  return src;
}

/// Crop to the bounding box of pixels with meaningful opacity.
img.Image _trim(img.Image src) {
  var minX = src.width, minY = src.height, maxX = 0, maxY = 0;
  for (final p in src) {
    if (p.a > 10) {
      minX = min(minX, p.x);
      minY = min(minY, p.y);
      maxX = max(maxX, p.x);
      maxY = max(maxY, p.y);
    }
  }
  if (maxX < minX) return src; // fully transparent — leave as-is
  return img.copyCrop(src,
      x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);
}

/// Center [glyph] on a [size]² canvas, scaled so its longest side is
/// [coverage] of the canvas. Indigo fill when [opaque], else transparent.
img.Image _compose(img.Image glyph, int size, double coverage,
    {required bool opaque}) {
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fill(canvas,
      color: opaque
          ? img.ColorRgba8(_bgR, _bgG, _bgB, 255)
          : img.ColorRgba8(0, 0, 0, 0));

  final scale = (size * coverage) / max(glyph.width, glyph.height);
  final resized = img.copyResize(
    glyph,
    width: (glyph.width * scale).round(),
    height: (glyph.height * scale).round(),
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    canvas,
    resized,
    dstX: ((size - resized.width) / 2).round(),
    dstY: ((size - resized.height) / 2).round(),
  );
  return canvas;
}

void _write(String path, img.Image image) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(image));
}
