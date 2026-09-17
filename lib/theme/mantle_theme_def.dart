import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// One colour theme as the web defines it: an id, a label, a corner radius and
/// a full token set per mode. The values live in `mantle_themes.g.dart`,
/// produced by `tool/generate_themes.dart` from the web's `themes.css`; this
/// file only holds the shape, so the generator emits data and nothing else.
@immutable
class MantleThemeDef {
  const MantleThemeDef({
    required this.id,
    required this.label,
    required this.radius,
    required this.light,
    required this.dark,
  });

  final String id;
  final String label;

  /// Corner radius in logical pixels (the web's `--radius`, rem × 16).
  final double radius;

  final MantleModeTokens light;
  final MantleModeTokens dark;

  MantleModeTokens forBrightness(Brightness b) =>
      b == Brightness.dark ? dark : light;
}

/// Every colour token the web emits for one theme in one mode, beyond what
/// [ShadColorScheme] can hold. The web's contract (see mantle
/// `packages/share-ui/themes/generate.mjs`): a FILL is tuned to sit behind its
/// own `-foreground`; an INK is the same role solved for text on the neutral
/// surfaces (background, card, popover, muted). Use the fill for meters, dots
/// and badges with `-foreground` text on them; use the ink for text or icons on
/// a themed surface. Bare fill-as-text is the web's lint error and is wrong
/// here too.
@immutable
class MantleModeTokens {
  const MantleModeTokens({
    required this.scheme,
    required this.swatches,
    required this.chart,
    required this.primaryInk,
    required this.destructiveInk,
    required this.success,
    required this.successForeground,
    required this.successInk,
    required this.warning,
    required this.warningForeground,
    required this.warningInk,
    required this.info,
    required this.infoForeground,
    required this.infoInk,
    required this.codeKeyword,
    required this.codeString,
    required this.codeNumber,
    required this.codeTitle,
    required this.codeVariable,
  });

  /// The shadcn tokens ShadApp threads through the tree.
  final ShadColorScheme scheme;

  /// Three picker preview colours: primary, accent, background — of THIS mode,
  /// so the picker shows what you would get in the mode you are in.
  final List<Color> swatches;

  /// `chart-1..chart-5`: categorical data ink, 3:1 against background + card.
  final List<Color> chart;

  final Color primaryInk;
  final Color destructiveInk;

  final Color success;
  final Color successForeground;
  final Color successInk;

  final Color warning;
  final Color warningForeground;
  final Color warningInk;

  final Color info;
  final Color infoForeground;
  final Color infoInk;

  /// The syntax palette: inks only (code sits on `muted`). Keyword keeps the
  /// theme's primary hue; string, number, title and variable are fixed
  /// semantic hues, so strings read green in every theme.
  final Color codeKeyword;
  final Color codeString;
  final Color codeNumber;
  final Color codeTitle;
  final Color codeVariable;
}
