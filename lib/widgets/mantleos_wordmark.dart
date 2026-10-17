import 'package:flutter/widgets.dart';

/// The MantleOS wordmark, tinted to whatever colour the surface needs.
///
/// The asset is the brand wordmark in a single flat colour on transparent, with
/// the "OS" knocked out of its tag, so `BlendMode.srcIn` repaints every opaque
/// pixel in [color] while keeping the anti-aliased edges, and the surface shows
/// through the "OS". That is why one PNG serves every theme — the full-colour
/// mark (see [MantleOSLockup]) would vanish on a rust or red header, and the
/// app ships a whole palette of themes (`kMantleThemes`).
///
/// Pass the token that matches the surface: `primaryForeground` on the primary
/// header bar, `foreground` on a plain background.
class MantleOSWordmark extends StatelessWidget {
  const MantleOSWordmark({super.key, required this.color, this.height = 22});

  final Color color;

  /// Height in logical pixels; width follows the mark's own ~4.15:1 ratio.
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MantleOS',
      image: true,
      child: Image.asset(
        'assets/brand/mantleos_wordmark.png',
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
