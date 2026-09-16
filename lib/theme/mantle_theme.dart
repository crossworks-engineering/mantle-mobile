import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'jackdaw_theme.dart';
// Twice on purpose: unprefixed for the MantleThemeDef type, prefixed for the
// generated list, whose name this file reuses for the combined registry below.
import 'mantle_themes.g.dart' hide kMantleThemes;
import 'mantle_themes.g.dart' as generated;

export 'jackdaw_theme.dart' show kJackdawTheme;
export 'mantle_themes.g.dart' show MantleThemeDef;

/// Every theme the picker offers: the app's own [kJackdawTheme] first, then the
/// themes ported from the web registry.
///
/// The Jackdaw entry is prepended here rather than added to
/// `mantle_themes.g.dart`, because `tool/generate_themes.dart` rewrites that
/// file from scratch and would drop it.
const List<MantleThemeDef> kMantleThemes = [
  kJackdawTheme,
  ...generated.kMantleThemes,
];

/// Builds [ShadThemeData] for any theme in [kMantleThemes] — the app's own
/// [kJackdawTheme] plus the themes ported from the web registry, whose colour
/// values live in `mantle_themes.g.dart` (produced by
/// `tool/generate_themes.dart`). This class only adds the shared text scale and
/// looks themes up.
abstract final class MantleTheme {
  /// The baseline theme id — used when nothing is stored or a persisted id is
  /// no longer in the registry. The app's own brand theme.
  static const String defaultId = 'jackdaw';

  /// The theme definition for [id], falling back to the default if unknown.
  static MantleThemeDef defFor(String id) => kMantleThemes.firstWhere(
        (t) => t.id == id,
        orElse: () => kMantleThemes.firstWhere((t) => t.id == defaultId),
      );

  static ShadThemeData light(String id) => _build(defFor(id), Brightness.light);
  static ShadThemeData dark(String id) => _build(defFor(id), Brightness.dark);

  static ShadThemeData _build(MantleThemeDef def, Brightness brightness) {
    return ShadThemeData(
      brightness: brightness,
      colorScheme: brightness == Brightness.dark ? def.dark : def.light,
      radius: BorderRadius.all(Radius.circular(def.radius)),
      textTheme: _textTheme(),
    );
  }

  /// Bumps every text style **+1pt** over shadcn's defaults — so the scale runs
  /// `small`/`muted` 15, body 17, `large` 19, `lead`/`h4` 21, `h3` 25, up to
  /// `h1Large` 49. 15 is the app's minimum font size; the +1 keeps a visible
  /// step between the smallest text and body. Colours are applied by the theme
  /// from [ShadColorScheme]. Shared across all color themes.
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
}

/// Exposes the active theme's `chart-1..chart-5` ramp to the widget tree. Unlike
/// the [ShadColorScheme] tokens (which ShadApp threads through automatically),
/// the chart colors have no shadcn home — the markdown renderer reads them from
/// here for callout accents, asides, and colour spans. Placed above `ShadApp`
/// so every route can resolve it.
class MantleColors extends InheritedWidget {
  const MantleColors({required this.def, required super.child, super.key});

  final MantleThemeDef def;

  /// chart-N (1-based, matching the web's `chart-1`..`chart-5`) for [brightness].
  /// Out-of-range N clamps into the palette.
  Color chart(Brightness brightness, int n) {
    final list = brightness == Brightness.dark ? def.darkChart : def.lightChart;
    return list[(n - 1).clamp(0, list.length - 1)];
  }

  /// Status colours — the web's `success` / `warning` / `info` roles. The
  /// ported themes carry no such tokens (shadcn only has `destructive`), so
  /// one set serves every theme, tuned per brightness. Fills only: use them
  /// for meters, dots and badges, never as text on a themed surface.
  Color success(Brightness b) =>
      b == Brightness.dark ? _StatusColors.successDark : _StatusColors.successLight;
  Color warning(Brightness b) =>
      b == Brightness.dark ? _StatusColors.warningDark : _StatusColors.warningLight;
  Color info(Brightness b) =>
      b == Brightness.dark ? _StatusColors.infoDark : _StatusColors.infoLight;

  /// Ink for text drawn ON a colour that is computed rather than themed (an
  /// agent's slug-derived avatar fill): black or white by the fill's own
  /// luminance, so the pairing rule holds for a fill no theme knows about.
  static Color inkOn(Color fill) =>
      fill.computeLuminance() > 0.45 ? _StatusColors.inkDark : _StatusColors.inkLight;

  static MantleColors of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<MantleColors>();
    assert(widget != null, 'No MantleColors found in context');
    return widget!;
  }

  @override
  bool updateShouldNotify(MantleColors oldWidget) => oldWidget.def.id != def.id;
}

/// The only colour literals outside the theme definitions. Status roles the
/// web has as tokens but the ported themes do not carry, plus the two inks
/// for computed fills. Kept here so `lib/features` stays literal-free (the
/// style ratchet test counts).
abstract final class _StatusColors {
  static const successLight = Color(0xFF15803D);
  static const successDark = Color(0xFF4ADE80);
  static const warningLight = Color(0xFFB45309);
  static const warningDark = Color(0xFFFBBF24);
  static const infoLight = Color(0xFF1D4ED8);
  static const infoDark = Color(0xFF60A5FA);
  static const inkLight = Color(0xFFFFFFFF);
  static const inkDark = Color(0xFF000000);
}
