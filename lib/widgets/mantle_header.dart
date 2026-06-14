import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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

/// Title for the leading slot of a [MantleHeader], in `primaryForeground`.
/// [wordmark] (default) sets it in Mantle's logo font (`BukhariScript`) for
/// brand/identity (e.g. the home `mantle` title); pass `wordmark: false` for a
/// plain screen title on sub-screens (Settings, Pending).
class MantleHeaderTitle extends StatelessWidget {
  const MantleHeaderTitle(this.text, {super.key, this.wordmark = true});

  final String text;
  final bool wordmark;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: wordmark
            ? TextStyle(
                fontFamily: 'BukhariScript',
                fontSize: 26,
                color: scheme.primaryForeground,
              )
            : TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: scheme.primaryForeground,
              ),
      ),
    );
  }
}
