// Wordmark generator — the MantleOS marks the app shows on its branded screens,
// and the one flutter_native_splash centres on the launch screen.
//
// Reads the MantleOS wordmark in branding/ (rust script "mantle" plus a rust
// tag with a cream "OS") and emits:
//
//   assets/brand/mantleos_logo.png      full colour — sign-in screens + launch screen
//   assets/brand/mantleos_wordmark.png  one flat colour, "OS" knocked out — the header
//
// The full-colour mark is the same artwork on light and dark grounds, so one
// file serves both brightnesses.
//
// The flat variant exists because the header bar takes every theme's primary
// colour, and a rust mark would vanish on a rust or red one. Every opaque pixel
// of it is a single colour, so MantleOSWordmark tints it to the bar's
// `primaryForeground` with BlendMode.srcIn. The cream "OS" can't survive that
// (it would be tinted too), so it becomes a hole in the tag and the bar colour
// shows through it instead.
//
// Re-run after changing the source art, then regenerate the launch screens:
//
//   fvm dart run tool/generate_lockups.dart
//   fvm dart run flutter_native_splash:create
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

/// Wordmark width at 4x density. ~1100px / 4 ≈ 275pt on screen, leaving a
/// comfortable margin on the narrowest phones (~390pt wide).
const _targetWidth = 1100;

const _source = 'branding/mantleos-logo-2048w.png';

/// The two colours of the wordmark: rust (the script and the tag) and cream
/// (the "OS"). Only the green channel tells them apart reliably — 0x3C vs 0xE7.
const _rustR = 0xC8, _rustG = 0x3C, _rustB = 0x04;
const _creamG = 0xE7;

void main() {
  final src = File(_source);
  if (!src.existsSync()) {
    stderr.writeln('✗ Missing ${src.path}');
    exit(1);
  }
  final decoded = img.decodePng(src.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('✗ Could not decode ${src.path}');
    exit(1);
  }

  final logo = _bleed(_trim(decoded));
  _emit('assets/brand/mantleos_logo.png', logo);
  _emit('assets/brand/mantleos_wordmark.png', _knockOut(logo));
}

void _emit(String path, img.Image glyph) {
  final scale = _targetWidth / glyph.width;
  final resized = img.copyResize(
    glyph,
    width: _targetWidth,
    height: (glyph.height * scale).round(),
    interpolation: img.Interpolation.cubic,
  );
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(resized));
  stdout.writeln('✅ wrote $path (${resized.width}x${resized.height})');
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

/// Give fully transparent pixels the rust colour instead of black, so
/// resampling doesn't darken the anti-aliased edges (every outer edge of the
/// mark is rust). Alpha is untouched.
img.Image _bleed(img.Image src) {
  for (final p in src) {
    if (p.a == 0) {
      p
        ..r = _rustR
        ..g = _rustG
        ..b = _rustB;
    }
  }
  return src;
}

/// The flat variant: every pixel rust, its alpha scaled by how much rust (as
/// opposed to cream) it held. Cream becomes transparent; the anti-aliased
/// seam between "OS" and the tag becomes a soft alpha edge.
img.Image _knockOut(img.Image src) {
  final out = img.Image(width: src.width, height: src.height, numChannels: 4);
  for (final p in src) {
    final cream = ((p.g - _rustG) / (_creamG - _rustG)).clamp(0.0, 1.0);
    final a = (p.a * (1 - cream)).round();
    out.setPixelRgba(p.x, p.y, _rustR, _rustG, _rustB, a);
  }
  return out;
}
