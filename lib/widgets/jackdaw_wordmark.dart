import 'package:flutter/widgets.dart';

/// The Jackdaw wordmark, tinted to whatever colour the surface needs.
///
/// The asset is the brand wordmark in a single flat colour (`#FDE7BC`) on
/// transparent, so `BlendMode.srcIn` repaints every opaque pixel in [color]
/// while keeping the anti-aliased edges. That is why one PNG serves every
/// theme — a multi-colour mark would need one asset per theme, and the app
/// ships a whole palette of them (`kMantleThemes`).
///
/// Pass the token that matches the surface: `primaryForeground` on the primary
/// header bar, `foreground` on a plain background.
class JackdawWordmark extends StatelessWidget {
  const JackdawWordmark({super.key, required this.color, this.height = 22});

  final Color color;

  /// Height in logical pixels; width follows the mark's own 4.57:1 ratio.
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Jackdaw',
      image: true,
      child: Image.asset(
        'assets/brand/jackdaw_wordmark.png',
        height: height,
        color: color,
        colorBlendMode: BlendMode.srcIn,
        fit: BoxFit.contain,
        // Excluded from semantics because the Semantics wrapper above already
        // names it; without this the tree carries the label twice.
        excludeFromSemantics: true,
      ),
    );
  }
}
