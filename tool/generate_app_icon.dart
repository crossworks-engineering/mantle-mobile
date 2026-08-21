// App-icon master generator.
//
// Takes the Jackdaw badge — the full-colour jackdaw in a cream-ringed circle,
// branding/jackdaw-icon-logo-dark-trans.png — and composes the two masters
// flutter_launcher_icons needs:
//
//   assets/icon/app_icon.png            1024² opaque, badge on brand brown  (iOS + legacy Android)
//   assets/icon/app_icon_foreground.png 1024² transparent badge             (Android adaptive foreground)
//
// Unlike the Mantle-era version this does NOT recolor the glyph. The badge is
// illustrated artwork — a flat white fill would erase the bird, the sunset
// stripes and the ring. It only trims the transparent margin and centers.
//
// The "dark" source is the variant drawn FOR a dark background (cream ring),
// which is why it pairs with [_brandBrown] rather than the cream.
//
// Re-run after changing the source, then fan out to the platforms:
//
//   fvm dart run tool/generate_app_icon.dart
//   fvm dart run flutter_launcher_icons
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

/// Jackdaw brand brown (#2D1500) — sampled from the ring of the light-background
/// badge, and the darkest swatch in brand/redesign/jackdaw-redesign.afpalette.
const _bgR = 0x2D, _bgG = 0x15, _bgB = 0x00;

/// Badge coverage (fraction of the canvas the badge's longest side fills).
///
/// iOS masks the square to a squircle; 0.86 leaves a brown frame wide enough
/// that the cream ring never touches the mask edge.
const _iosCoverage = 0.86;

/// The badge's cream field is only ~32% opaque — the artwork was drawn against
/// a light page, and compositing it straight onto [_bgR]/[_bgG]/[_bgB] turns
/// the interior a muddy olive. So the badge gets its own opaque disc first.
/// The brand cream (#FDE7BC) is used rather than white: it matches the ring
/// exactly, so the narrow transparent gap just inside the ring stops reading as
/// a bright white seam.
const _backingR = 0xFD, _backingG = 0xE7, _backingB = 0xBC;

/// The disc is inset so its edge hides beneath the cream ring (measured at 2.9%
/// of the badge width) instead of fringing outside it.
const _backingInset = 0.985;

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

void main() {
  final src = File('branding/jackdaw-icon-logo-dark-trans.png');
  if (!src.existsSync()) {
    stderr.writeln('✗ Missing ${src.path}');
    exit(1);
  }
  final logo = img.decodePng(src.readAsBytesSync());
  if (logo == null) {
    stderr.writeln('✗ Could not decode ${src.path}');
    exit(1);
  }

  final badge = _backDisc(_trim(logo));

  _write('assets/icon/app_icon.png',
      _compose(badge, 1024, _iosCoverage, opaque: true));
  _write('assets/icon/app_icon_foreground.png',
      _compose(badge, 1024, _adaptiveCoverage, opaque: false));

  stdout.writeln('✅ wrote assets/icon/app_icon.png + app_icon_foreground.png');
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

/// Lay [badge] over an opaque disc filling its own (elliptical) bounds, inset by
/// [_backingInset] so the disc edge sits under the cream ring. Restores the
/// interior to the colours the artwork was drawn with, and makes the badge
/// opaque so it reads the same on any background.
img.Image _backDisc(img.Image badge) {
  final canvas =
      img.Image(width: badge.width, height: badge.height, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  final cx = (badge.width - 1) / 2, cy = (badge.height - 1) / 2;
  final rx = cx * _backingInset, ry = cy * _backingInset;
  final disc = img.ColorRgba8(_backingR, _backingG, _backingB, 255);
  for (var y = 0; y < badge.height; y++) {
    for (var x = 0; x < badge.width; x++) {
      final dx = (x - cx) / rx, dy = (y - cy) / ry;
      if (dx * dx + dy * dy <= 1.0) canvas.setPixel(x, y, disc);
    }
  }
  img.compositeImage(canvas, badge);
  return canvas;
}

/// Center [badge] on a [size]² canvas, scaled so its longest side is [coverage]
/// of the canvas. Brand-brown fill when [opaque], else transparent.
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
