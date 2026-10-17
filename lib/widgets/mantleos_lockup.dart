import 'package:flutter/widgets.dart';

/// The full-colour MantleOS wordmark — rust script "mantle" and a rust tag with
/// a cream "OS" — for the screens that introduce the app: server setup and
/// sign-in. The launch screen centres the same image.
///
/// Unlike [MantleOSWordmark] this is never tinted: the tag's cream "OS" is part
/// of the mark. The artwork is drawn to read on light and dark grounds alike,
/// so one asset serves both brightnesses.
class MantleOSLockup extends StatelessWidget {
  const MantleOSLockup({super.key, this.height = 48});

  /// Height in logical pixels; width follows the mark's own ~4.15:1 ratio.
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MantleOS',
      image: true,
      child: Image.asset(
        'assets/brand/mantleos_logo.png',
        height: height,
        fit: BoxFit.contain,
        // The Semantics wrapper above already names it; without this the tree
        // carries the label twice.
        excludeFromSemantics: true,
      ),
    );
  }
}
