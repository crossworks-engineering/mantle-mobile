import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'mantle_themes.g.dart';

/// The app's own theme, drawn from the Jackdaw mark rather than ported from the
/// web registry — which is why it is hand-written and lives OUTSIDE
/// `mantle_themes.g.dart`. `tool/generate_themes.dart` overwrites that file
/// wholesale, so anything added there would be lost on the next run.
///
/// The two anchors are sampled from the artwork in `branding/`: the deep brown
/// `#2D1500` of the badge ring and the cream `#FDE7BC` of the wordmark. The
/// chart ramp is the badge's own sunset stripes, warm to dark.
///
/// `primary` is deliberately the brown, not one of the brighter stripes: the
/// app paints its header bar with `primary` and the wordmark with
/// `primaryForeground`, so a brown bar carrying the cream mark reproduces the
/// app icon exactly. Dark mode inverts the pair, the way the ported themes
/// lighten their accent.
const MantleThemeDef kJackdawTheme = MantleThemeDef(
  id: 'jackdaw',
  label: 'Jackdaw',
  radius: 8.0,
  swatches: [Color(0xFF2D1500), Color(0xFFE06800), Color(0xFFFDE7BC)],
  light: ShadColorScheme(
    background: Color(0xFFFAF3E6),
    foreground: Color(0xFF2D1500),
    card: Color(0xFFFFFCF5),
    cardForeground: Color(0xFF2D1500),
    popover: Color(0xFFFFFCF5),
    popoverForeground: Color(0xFF2D1500),
    primary: Color(0xFF2D1500),
    primaryForeground: Color(0xFFFDE7BC),
    secondary: Color(0xFFEFE2C8),
    secondaryForeground: Color(0xFF4A2A0A),
    muted: Color(0xFFF2E8D5),
    mutedForeground: Color(0xFF7C6144),
    accent: Color(0xFFF7E3C4),
    accentForeground: Color(0xFF3D1D00),
    destructive: Color(0xFFC0271B),
    destructiveForeground: Color(0xFFFFF6E6),
    border: Color(0xFFE0CFAE),
    input: Color(0xFFE0CFAE),
    ring: Color(0xFFC03800),
    selection: Color(0xFFF2DEBB),
  ),
  dark: ShadColorScheme(
    background: Color(0xFF180B00),
    foreground: Color(0xFFFDE7BC),
    card: Color(0xFF2A1400),
    cardForeground: Color(0xFFFDE7BC),
    popover: Color(0xFF2A1400),
    popoverForeground: Color(0xFFFDE7BC),
    primary: Color(0xFFFDE7BC),
    primaryForeground: Color(0xFF2D1500),
    secondary: Color(0xFF3D2208),
    secondaryForeground: Color(0xFFF0DCB8),
    muted: Color(0xFF241000),
    mutedForeground: Color(0xFFB49A76),
    accent: Color(0xFF4A2A0A),
    accentForeground: Color(0xFFF0DCB8),
    destructive: Color(0xFFE5533D),
    destructiveForeground: Color(0xFF2A1400),
    border: Color(0xFF4A3419),
    input: Color(0xFF4A3419),
    ring: Color(0xFFE0A020),
    selection: Color(0xFF4A2A0A),
  ),
  // The badge's sunset stripes, brightest first.
  lightChart: [
    Color(0xFFE0A020),
    Color(0xFFE06800),
    Color(0xFFC03800),
    Color(0xFF8A3A08),
    Color(0xFF581800),
  ],
  darkChart: [
    Color(0xFFF0BC50),
    Color(0xFFE88A2A),
    Color(0xFFD45A18),
    Color(0xFFA84410),
    Color(0xFF7A2E00),
  ],
);
