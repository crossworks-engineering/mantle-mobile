// App-icon master generator.
//
// Takes the MantleOS sun badge — branding/mantleos-icon-2048.png, a round badge
// (deep rust ring, rust sun, amber/orange/rust bands) that is fully opaque
// inside the circle and transparent outside — and composes the masters
// flutter_launcher_icons and flutter_native_splash need:
//
//   assets/icon/app_icon.png             1024² opaque, badge on brand cream  (iOS + legacy Android)
//   assets/icon/app_icon_foreground.png  1024² transparent badge             (Android adaptive foreground)
//   assets/icon/splash_android12.png     1152² transparent badge             (Android 12+ launch screen)
//
// The badge is illustrated artwork, so it is never recoloured: this only trims
// the transparent margin, scales and centres.
//
// The ground is cream, not brown: the badge's outer ring is a deep rust
// (#5C1E02) that disappears against the brand brown.
//
// Re-run after changing the source, then fan out to the platforms:
//
//   fvm dart run tool/generate_app_icon.dart
//   fvm dart run flutter_launcher_icons
//   fvm dart run flutter_native_splash:create
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

/// MantleOS brand cream (#FDE7BC) — the icon's ground.
const _bgR = 0xFD, _bgG = 0xE7, _bgB = 0xBC;

/// Badge coverage (fraction of the canvas the badge's diameter fills).
///
/// iOS masks the square to a squircle; 0.86 leaves a cream frame wide enough
/// that the badge's ring never touches the mask edge.
const _iosCoverage = 0.86;

/// Android adaptive icons only guarantee the central 66dp of the 108dp canvas
/// — a safe-zone fraction of 66/108 ≈ 0.61.
///
/// Do NOT set this to 0.61 directly. flutter_launcher_icons wraps the
/// foreground in `<inset android:inset="16%">` (see the generated
/// mipmap-anydpi-v26/ic_launcher.xml), which already shrinks the drawable to
/// 68% of its box. Insetting here as well would double-count and leave the
/// badge floating at ~0.42 of the canvas. 0.90 × 0.68 ≈ 0.61 lands exactly on
/// the safe zone.
const _adaptiveCoverage = 0.90;

/// The Android 12+ launch screen masks its icon to a circle 2/3 of the canvas
/// across (768px of 1152px), with no inset of its own. The badge sits a little
/// inside that so its ring is never clipped, and the splash's cream icon
/// background (pubspec.yaml) shows as a thin frame around it.
const _android12Size = 1152;
const _android12Coverage = 0.62;

void main() {
  final src = File('branding/mantleos-icon-2048.png');
  if (!src.existsSync()) {
    stderr.writeln('✗ Missing ${src.path}');
    exit(1);
  }
  final logo = img.decodePng(src.readAsBytesSync());
  if (logo == null) {
    stderr.writeln('✗ Could not decode ${src.path}');
    exit(1);
  }

  final badge = _bleed(_trim(logo));

  _write('assets/icon/app_icon.png',
      _compose(badge, 1024, _iosCoverage, opaque: true));
  _write('assets/icon/app_icon_foreground.png',
      _compose(badge, 1024, _adaptiveCoverage, opaque: false));
  _write('assets/icon/splash_android12.png',
      _compose(badge, _android12Size, _android12Coverage, opaque: false));

  stdout.writeln('✅ wrote assets/icon/app_icon.png, app_icon_foreground.png '
      '+ splash_android12.png');
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

/// Give fully transparent pixels the ring's colour (#5C1E02) instead of black.
///
/// Resampling mixes a pixel's colour with its neighbours' regardless of their
/// alpha, so transparent black just outside the circle would darken the
/// anti-aliased rim. Alpha is untouched, so nothing visible changes.
img.Image _bleed(img.Image src) {
  for (final p in src) {
    if (p.a == 0) {
      p
        ..r = 0x5C
        ..g = 0x1E
        ..b = 0x02;
    }
  }
  return src;
}

/// Center [badge] on a [size]² canvas, scaled so its longest side is [coverage]
/// of the canvas. Brand-cream fill when [opaque], else transparent.
img.Image _compose(img.Image badge, int size, double coverage,
    {required bool opaque}) {
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fill(canvas,
      color: opaque
          ? img.ColorRgba8(_bgR, _bgG, _bgB, 255)
          : img.ColorRgba8(0, 0, 0, 0));

  final scale = (size * coverage) / max(badge.width, badge.height);
  final resized = img.copyResize(
    badge,
    width: (badge.width * scale).round(),
    height: (badge.height * scale).round(),
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
