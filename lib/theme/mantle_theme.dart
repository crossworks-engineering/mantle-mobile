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

  static ShadThemeData light() => ShadThemeData(
    brightness: Brightness.light,
    colorScheme: lightColors,
    radius: _radius,
  );

  static ShadThemeData dark() => ShadThemeData(
    brightness: Brightness.dark,
    colorScheme: darkColors,
    radius: _radius,
  );
}
