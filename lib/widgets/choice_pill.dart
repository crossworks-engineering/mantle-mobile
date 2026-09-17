import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// One choice in a row of pills (tag filters, reminder leads, priority). The
/// pill itself is small (`secondary`, or `primary` when selected); vertical
/// padding makes the 44pt target, which works the same inside a `Wrap` and
/// a horizontal list (a centred box would take a Wrap's whole row).
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.semanticLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// What a screen reader says when the visible label is shorthand.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? scheme.primary : scheme.secondary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: theme.textTheme.small.copyWith(
                color: selected
                    ? scheme.primaryForeground
                    : scheme.secondaryForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
