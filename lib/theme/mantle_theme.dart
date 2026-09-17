import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'mantle_themes.g.dart';

export 'mantle_theme_def.dart';

/// Every theme the picker offers: the web's registry, in the web's order, as
/// ported by `tool/generate_themes.dart` into `mantle_themes.g.dart`. The
/// phone adds nothing of its own: the brand themes (`jackdaw`,
/// `jackdaw-harvest`, `pinnacle`) are authored once, in mantle's seeds, and
/// arrive here through the same port as every other theme.
const List<MantleThemeDef> kMantleThemes = kGeneratedThemes;

/// Builds [ShadThemeData] for any theme in [kMantleThemes]. This class only
/// adds the shared text scale and looks themes up; the colour values live in
/// the generated file.
abstract final class MantleTheme {
  /// The baseline theme id — used when nothing is stored, no brain theme is
  /// known, or a persisted id is no longer in the registry. The brand theme
  /// (the web's own default is `clean-slate`; the phone opens on its brand).
  static const String defaultId = 'jackdaw';

  /// The theme definition for [id], falling back to the default if unknown.
  static MantleThemeDef defFor(String id) => kMantleThemes.firstWhere(
        (t) => t.id == id,
        orElse: () => kMantleThemes.firstWhere((t) => t.id == defaultId),
      );

  /// Whether [id] names a theme in the registry.
  static bool has(String? id) =>
      id != null && kMantleThemes.any((t) => t.id == id);

  static ShadThemeData light(String id) => _build(defFor(id), Brightness.light);
  static ShadThemeData dark(String id) => _build(defFor(id), Brightness.dark);

  static ShadThemeData _build(MantleThemeDef def, Brightness brightness) {
    return ShadThemeData(
      brightness: brightness,
      colorScheme: def.forBrightness(brightness).scheme,
      radius: BorderRadius.all(Radius.circular(def.radius)),
      textTheme: _textTheme(),
      // Every regular button is a 44pt target (shadcn's default is 40). Set
      // once here rather than per call site; `lg` stays for the rare big one.
      buttonSizesTheme: const ShadButtonSizesTheme(
        regular: ShadButtonSizeTheme(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
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

/// Exposes the active theme's tokens beyond [ShadColorScheme] to the widget
/// tree: the chart ramp, the status roles (success / warning / info, each as a
/// fill, its `-foreground`, and its ink), the primary and destructive inks,
/// and the code palette. ShadApp threads the scheme through automatically;
/// these have no shadcn home, so they ride an InheritedWidget placed above
/// `ShadApp` where every route can resolve it.
///
/// Every value is PER THEME, ported from the web's `themes.css`: a `mono`
/// success is as quiet as its own destructive, a `cyberpunk` one as loud.
/// Fill vs ink: a fill (`success`) goes behind `successForeground` text — a
/// meter, a dot, a badge; an ink (`successInk`) is the same role solved for
/// text or an icon on a themed surface. Never use a fill as text.
class MantleColors extends InheritedWidget {
  const MantleColors({required this.def, required super.child, super.key});

  final MantleThemeDef def;

  /// The full token set for [brightness].
  MantleModeTokens tokens(Brightness brightness) => def.forBrightness(brightness);

  /// chart-N (1-based, matching the web's `chart-1`..`chart-5`) for [brightness].
  /// Out-of-range N clamps into the palette.
  Color chart(Brightness brightness, int n) {
    final list = tokens(brightness).chart;
    return list[(n - 1).clamp(0, list.length - 1)];
  }

  // Status fills — behind their own -foreground; meters, dots, badges.
  Color success(Brightness b) => tokens(b).success;
  Color warning(Brightness b) => tokens(b).warning;
  Color info(Brightness b) => tokens(b).info;

  // Status inks — text or an icon on a themed surface.
  Color successInk(Brightness b) => tokens(b).successInk;
  Color warningInk(Brightness b) => tokens(b).warningInk;
  Color infoInk(Brightness b) => tokens(b).infoInk;

  /// Ink for text drawn ON a colour that is computed rather than themed (an
  /// agent's slug-derived avatar fill): black or white by the fill's own
  /// luminance, so the pairing rule holds for a fill no theme knows about.
  /// The only two colour literals outside the generated registry.
  static Color inkOn(Color fill) => fill.computeLuminance() > 0.45
      ? const Color(0xFF000000)
      : const Color(0xFFFFFFFF);

  static MantleColors of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<MantleColors>();
    assert(widget != null, 'No MantleColors found in context');
    return widget!;
  }

  @override
  bool updateShouldNotify(MantleColors oldWidget) => oldWidget.def.id != def.id;
}
