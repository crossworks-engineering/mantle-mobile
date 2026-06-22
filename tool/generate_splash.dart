// Splash-image master generator.
//
// Takes the brand wordmark (a black "mantle" on transparent —
// branding/mantle_logo_full.png) and produces the white wordmark master that
// flutter_native_splash centers on the indigo launch screen:
//
//   assets/splash/mantle_wordmark_white.png   white "mantle", transparent, ~4x density
//
// It recolors the glyph white (preserving anti-aliased edges), trims the
// transparent margins, then scales it to a sensible launch-screen width.
// flutter_native_splash treats the source as 4x and downscales to @3x/@2x, so
// the on-screen width is roughly [_targetWidth] / 4 in points. Re-run after
// changing the source, then regenerate the platform splashes:
//
//   fvm dart run tool/generate_splash.dart
//   fvm dart run flutter_native_splash:create
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

/// White wordmark width at 4x density. ~1000px / 4 ≈ 250pt on screen, leaving a
/// comfortable margin on the narrowest phones (~390pt wide).
const _targetWidth = 1000;

void main() {
  final src = File('branding/mantle_logo_full.png');
  if (!src.existsSync()) {
    stderr.writeln('✗ Missing ${src.path}');
    exit(1);
  }
  final wordmark = img.decodePng(src.readAsBytesSync());
  if (wordmark == null) {
    stderr.writeln('✗ Could not decode ${src.path}');
    exit(1);
  }

  final glyph = _trim(_recolorWhite(wordmark));
  final scale = _targetWidth / glyph.width;
  final resized = img.copyResize(
    glyph,
    width: _targetWidth,
    height: (glyph.height * scale).round(),
    interpolation: img.Interpolation.cubic,
  );

  _write('assets/splash/mantle_wordmark_white.png', resized);
  stdout.writeln('✅ wrote assets/splash/mantle_wordmark_white.png '
      '(${resized.width}x${resized.height})');
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

void _write(String path, img.Image image) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(image));
}
