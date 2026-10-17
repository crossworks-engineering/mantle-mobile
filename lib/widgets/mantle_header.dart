import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'mantleos_wordmark.dart';

/// The app's standard header: a flat primary-filled bar that runs edge-to-edge
/// under the status bar. [leading] (identity/title) fills the start; [trailing]
/// actions sit at the end. Use it on every screen with a header — see
/// docs/styling-guide.md "Headers".
class MantleHeader extends StatelessWidget {
  const MantleHeader({
    super.key,
    required this.leading,
    this.trailing = const [],
  });

  /// The identity/title at the start of the bar (e.g. agent identity, wordmark).
  final Widget leading;

  /// Action widgets at the end (e.g. back, theme toggle). Built by the caller
  /// with `primaryForeground` so they read against the primary fill.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Container(
      color: scheme.primary,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 4, 0),
            child: Row(
              children: [
                Expanded(child: leading),
                ...trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An icon-only action for the header's trailing slot: a ghost button in
/// `primaryForeground`, 44pt tall from the theme, and named for screen
/// readers by [label] (the icon carries it, the button supplies the role).
class HeaderAction extends StatelessWidget {
  const HeaderAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 20,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fg = ShadTheme.of(context).colorScheme.primaryForeground;
    return ShadButton.ghost(
      onPressed: onPressed,
      child: Icon(icon, size: size, color: fg, semanticLabel: label),
    );
  }
}

/// Title for the leading slot of a [MantleHeader], in `primaryForeground`.
///
/// [wordmark] (default) draws the MantleOS brand mark itself and ignores [text]
/// apart from using it as the accessibility label — the wordmark is custom
/// lettering, so it cannot be reproduced by setting type. Pass
/// `wordmark: false` for a plain screen title on sub-screens (Settings,
/// Pending).
class MantleHeaderTitle extends StatelessWidget {
  const MantleHeaderTitle(this.text, {super.key, this.wordmark = true});

  final String text;
  final bool wordmark;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: wordmark
          ? MantleOSWordmark(color: theme.colorScheme.primaryForeground)
          : Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: headerTitleStyle(theme),
            ),
    );
  }
}

/// The one style for a title in the primary header bar: the scale's `h4` in
/// `primaryForeground`. Sub-screen titles and the chat's agent name share it;
/// the script face is reserved for the MantleOS wordmark itself.
TextStyle headerTitleStyle(ShadThemeData theme) =>
    theme.textTheme.h4.copyWith(color: theme.colorScheme.primaryForeground);
