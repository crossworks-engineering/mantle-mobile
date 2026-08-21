// Lockup generator — the badge-plus-wordmark marks the app shows on its
// branded screens, and the one flutter_native_splash centres on the launch
// screen.
//
// Reads the two horizontal lockups in branding/ and emits:
//
//   assets/brand/jackdaw_lockup_dark.png    cream mark, for DARK backgrounds
//   assets/brand/jackdaw_lockup_light.png   brown mark, for LIGHT backgrounds
//
// `dark`/`light` name the background the mark is drawn FOR, not its own colour.
// Two assets are needed because the badge is illustrated artwork — unlike the
// flat wordmark (see JackdawWordmark), it cannot be tinted to a theme token.
//
// The badge half gets an opaque disc slid underneath it first: its cream field
// is only ~32% opaque, because the artwork was drawn against a light page. Skip
// that and the interior goes muddy on any dark ground — and it still looks
// right in every image viewer, which shows it on white. The wordmark half is
// already fully opaque and is left alone.
//
// Re-run after changing the source art, then regenerate the launch screens:
//
//   fvm dart run tool/generate_lockups.dart
//   fvm dart run flutter_native_splash:create
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

/// Lockup width at 4x density. ~1100px / 4 ≈ 275pt on screen, leaving a
/// comfortable margin on the narrowest phones (~390pt wide).
const _targetWidth = 1100;

/// Brand cream — the disc laid under the badge. Matches the badge's own ring so
/// the seam between them disappears. Keep in step with the same constant in
/// tool/generate_app_icon.dart.
const _backingR = 0xFD, _backingG = 0xE7, _backingB = 0xBC;

/// Inset so the disc edge hides beneath the badge's ring.
const _backingInset = 0.985;

const _sources = {
  'dark': 'branding/jackdaw-icon-name-logo-dark-row-trans.png',
  'light': 'branding/jackdaw-icon-name-logo-light-row-trans.png',
};

void main() {
  for (final entry in _sources.entries) {
    final src = File(entry.value);
    if (!src.existsSync()) {
      stderr.writeln('✗ Missing ${src.path}');
      exit(1);
    }
    final lockup = img.decodePng(src.readAsBytesSync());
    if (lockup == null) {
      stderr.writeln('✗ Could not decode ${src.path}');
      exit(1);
    }

    final glyph = _backBadgeDisc(_trim(lockup));
    final scale = _targetWidth / glyph.width;
    final resized = img.copyResize(
      glyph,
      width: _targetWidth,
      height: (glyph.height * scale).round(),
      interpolation: img.Interpolation.cubic,
    );

    final out = 'assets/brand/jackdaw_lockup_${entry.key}.png';
    _write(out, resized);
    stdout.writeln('✅ wrote $out (${resized.width}x${resized.height})');
  }
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

/// Slide an opaque cream disc UNDER the badge at the left of a trimmed [lockup],
/// leaving the wordmark untouched.
///
/// The badge's width is found as the first fully transparent column — the gap
/// the artwork leaves between badge and wordmark — so this keeps working if the
/// lockup's spacing or proportions change.
img.Image _backBadgeDisc(img.Image lockup) {
  final badgeW = _firstEmptyColumn(lockup);
  if (badgeW <= 0) {
    stderr.writeln('⚠ no gap found between badge and wordmark — '
        'leaving the lockup unbacked');
    return lockup;
  }

  final canvas =
      img.Image(width: lockup.width, height: lockup.height, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  final cx = (badgeW - 1) / 2, cy = (lockup.height - 1) / 2;
  final rx = cx * _backingInset, ry = cy * _backingInset;
  final disc = img.ColorRgba8(_backingR, _backingG, _backingB, 255);
  for (var y = 0; y < lockup.height; y++) {
    for (var x = 0; x < badgeW; x++) {
      final dx = (x - cx) / rx, dy = (y - cy) / ry;
      if (dx * dx + dy * dy <= 1.0) canvas.setPixel(x, y, disc);
    }
  }
  img.compositeImage(canvas, lockup);
  return canvas;
}

/// x of the first column with no opaque pixel at all, or -1 if there is none.
int _firstEmptyColumn(img.Image src) {
  for (var x = 0; x < src.width; x++) {
    var any = false;
    for (var y = 0; y < src.height; y++) {
      if (src.getPixel(x, y).a > 10) {
        any = true;
        break;
      }
    }
    if (!any) return x;
  }
  return -1;
}

void _write(String path, img.Image image) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(image));
}
