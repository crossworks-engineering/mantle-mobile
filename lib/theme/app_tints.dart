import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The 13 named tints a folder or an item tile can carry.
///
/// The brain stores the KEY (`blue`), never a colour, and each client paints
/// it against its own theme so a tile stays legible on every theme and in
/// both modes. The web does it in CSS (jackdaw `client/web/app/globals.css`):
///
///     --color-app-tint-<key>:     color-mix(in oklab, <hue> 18%, background)
///     --color-app-tint-<key>-ink: color-mix(in oklab, <hue> 72%, foreground)
///
/// This is the same mix, in Dart. The hues below are the web's `--app-hue-*`
/// values converted from oklch to sRGB; they are the one set of colour
/// literals outside the generated theme port, and they live in `lib/theme`
/// where literals are allowed.
abstract final class AppTints {
  static const Map<String, Color> _hues = {
    'slate': Color(0xFF62748E),
    'red': Color(0xFFFB2C36),
    'orange': Color(0xFFFF6900),
    'amber': Color(0xFFFE9A00),
    'lime': Color(0xFF7CCF00),
    'green': Color(0xFF00C950),
    'teal': Color(0xFF00BBA7),
    'cyan': Color(0xFF00B8DB),
    'sky': Color(0xFF00A6F4),
    'blue': Color(0xFF2B7FFF),
    'indigo': Color(0xFF615FFF),
    'violet': Color(0xFF8E51FF),
    'pink': Color(0xFFF6339A),
  };

  static Iterable<String> get keys => _hues.keys;

  /// The tile fill for [key] on a theme whose page colour is [background], or
  /// null when [key] is not a tint this build knows.
  static Color? fill(String? key, Color background) {
    final hue = _hues[key];
    return hue == null ? null : mixOklab(hue, background, 0.18);
  }

  /// The ink (icon or text on the fill) for [key], solved against the theme's
  /// [foreground].
  static Color? ink(String? key, Color foreground) {
    final hue = _hues[key];
    return hue == null ? null : mixOklab(hue, foreground, 0.72);
  }
}

/// CSS `color-mix(in oklab, a t, b)`: [t] of [a], the rest of [b], mixed in
/// the OKLab space so a tint keeps its hue instead of greying the way an
/// sRGB lerp does.
Color mixOklab(Color a, Color b, double t) {
  final la = _toOklab(a), lb = _toOklab(b);
  double mix(int i) => la[i] * t + lb[i] * (1 - t);
  return _fromOklab(mix(0), mix(1), mix(2), a.a * t + b.a * (1 - t));
}

double _linear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _gamma(double c) {
  final v = c.clamp(0.0, 1.0);
  return v <= 0.0031308
      ? 12.92 * v
      : 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;
}

double _cbrt(double v) =>
    v < 0 ? -math.pow(-v, 1 / 3).toDouble() : math.pow(v, 1 / 3).toDouble();

List<double> _toOklab(Color c) {
  final r = _linear(c.r), g = _linear(c.g), b = _linear(c.b);
  final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  return [
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  ];
}

Color _fromOklab(double lightness, double a, double b, double alpha) {
  final l = math.pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3);
  final m = math.pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3);
  final s = math.pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3);
  return Color.from(
    alpha: alpha,
    red: _gamma(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
    green: _gamma(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
    blue: _gamma(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s),
  );
}
