import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Color tokens lifted from Mantle's web theme system — the default
/// **Clean Slate** theme (`apps/web/app/globals.css`, the `:root` / `.dark`
/// blocks). The web stores these as oklch; the values here are the sRGB
/// conversions. `selection` has no web equivalent, so it mirrors `accent`.
///
/// If the web Clean Slate theme changes, re-convert and update these.
abstract final class MantleTheme {
  /// `--radius: 0.5rem` → 8 logical px (same in light and dark for Clean Slate).
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(8));

  static const ShadColorScheme lightColors = ShadColorScheme(
    background: Color(0xFFF8FAFC),
    foreground: Color(0xFF1E293B),
    card: Color(0xFFFFFFFF),
    cardForeground: Color(0xFF1E293B),
    popover: Color(0xFFFFFFFF),
    popoverForeground: Color(0xFF1E293B),
    primary: Color(0xFF6366F1),
    primaryForeground: Color(0xFFFFFFFF),
    secondary: Color(0xFFE5E7EB),
    secondaryForeground: Color(0xFF374151),
    muted: Color(0xFFF3F4F6),
    mutedForeground: Color(0xFF6B7280),
    accent: Color(0xFFE0E7FF),
    accentForeground: Color(0xFF374151),
    destructive: Color(0xFFEF4444),
    destructiveForeground: Color(0xFFFFFFFF),
    border: Color(0xFFD1D5DB),
    input: Color(0xFFD1D5DB),
    ring: Color(0xFF6366F1),
    selection: Color(0xFFE0E7FF),
  );

  static const ShadColorScheme darkColors = ShadColorScheme(
    background: Color(0xFF0F172A),
    foreground: Color(0xFFE2E8F0),
    card: Color(0xFF1E293B),
    cardForeground: Color(0xFFE2E8F0),
    popover: Color(0xFF1E293B),
    popoverForeground: Color(0xFFE2E8F0),
    primary: Color(0xFF818CF8),
    primaryForeground: Color(0xFF0F172A),
    secondary: Color(0xFF2D3748),
    secondaryForeground: Color(0xFFD1D5DB),
    muted: Color(0xFF152032),
    mutedForeground: Color(0xFF9CA3AF),
    accent: Color(0xFF374151),
    accentForeground: Color(0xFFD1D5DB),
    destructive: Color(0xFFEF4444),
    destructiveForeground: Color(0xFF0F172A),
    border: Color(0xFF4B5563),
    input: Color(0xFF4B5563),
    ring: Color(0xFF818CF8),
    selection: Color(0xFF374151),
  );

  /// `--chart-1`..`--chart-5` from Clean Slate (the indigo ramp), used by the
  /// markdown renderer for callout accents, asides, and colour spans. Index 0 =
  /// chart-1. sRGB conversions of the web oklch values.
  static const List<Color> lightChart = [
    Color(0xFF6366F1), // chart-1 (== primary)
    Color(0xFF4F46E5), // chart-2
    Color(0xFF4338CA), // chart-3
    Color(0xFF3730A3), // chart-4
    Color(0xFF312E81), // chart-5
  ];

  static const List<Color> darkChart = [
    Color(0xFF818CF8), // chart-1 (== primary)
    Color(0xFF6366F1), // chart-2
    Color(0xFF4F46E5), // chart-3
    Color(0xFF4338CA), // chart-4
    Color(0xFF3730A3), // chart-5
  ];

  /// chart-N (1-based, matching Mantle's `chart-1`..`chart-5`) for the given
  /// brightness. Out-of-range N clamps into the palette.
  static Color chart(Brightness brightness, int n) {
    final list = brightness == Brightness.dark ? darkChart : lightChart;
    return list[(n - 1).clamp(0, list.length - 1)];
  }

  /// Bumps every text style **+1pt** over shadcn's defaults — so the scale runs
  /// `small`/`muted` 15, body 17, `large` 19, `lead`/`h4` 21, `h3` 25, up to
  /// `h1Large` 49. 15 is the app's minimum font size; the +1 keeps a visible
  /// step between the smallest text and body. Colours are applied by the theme
  /// from [ShadColorScheme].
  static ShadTextTheme _textTheme() {
    final base = ShadTextTheme();
    TextStyle up(TextStyle s) => s.copyWith(fontSize: (s.fontSize ?? 14) + 1);
    return base.copyWith(
      h1Large: up(base.h1Large),
      h1: up(base.h1),
      h2: up(base.h2),
      h3: up(base.h3),
      h4: up(base.h4),
      p: up(base.p),
      blockquote: up(base.blockquote),
      table: up(base.table),
      list: up(base.list),
      lead: up(base.lead),
      large: up(base.large),
      small: up(base.small),
      muted: up(base.muted),
    );
  }

  static ShadThemeData light() => ShadThemeData(
    brightness: Brightness.light,
    colorScheme: lightColors,
    radius: _radius,
    textTheme: _textTheme(),
  );

  static ShadThemeData dark() => ShadThemeData(
    brightness: Brightness.dark,
    colorScheme: darkColors,
    radius: _radius,
    textTheme: _textTheme(),
  );
}
