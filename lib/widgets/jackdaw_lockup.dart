import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// The full Jackdaw mark — the illustrated badge next to the wordmark — for the
/// screens that introduce the app: server setup and sign-in.
///
/// Unlike [JackdawWordmark] this cannot be tinted. The badge is illustrated
/// artwork, so `BlendMode.srcIn` would flatten the bird, the sunset stripes and
/// the ring into one colour. Two assets ship instead, and the one that suits
/// the current brightness is chosen here: the cream mark on dark surfaces, the
/// brown mark on light ones.
class JackdawLockup extends StatelessWidget {
  const JackdawLockup({super.key, this.height = 56});

  /// Height in logical pixels; width follows the mark's own ~3.5:1 ratio.
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = ShadTheme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'Jackdaw',
      image: true,
      child: Image.asset(
        dark
            ? 'assets/brand/jackdaw_lockup_dark.png'
            : 'assets/brand/jackdaw_lockup_light.png',
        height: height,
        fit: BoxFit.contain,
        // The Semantics wrapper above already names it; without this the tree
        // carries the label twice.
        excludeFromSemantics: true,
      ),
    );
  }
}
