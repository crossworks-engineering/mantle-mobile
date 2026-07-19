import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/chat/turn_meta.dart';

/// Icon for a thought step's coarse `kind`. The producer's set is open-ended
/// ('web', 'compute', 'file', 'person', …) — map the common buckets and
/// default the rest to a wrench.
IconData iconForStepKind(String kind) {
  switch (kind) {
    case 'thinking':
      return LucideIcons.brain;
    case 'web':
      return LucideIcons.globe;
    case 'compute':
      return LucideIcons.cpu;
    case 'file':
      return LucideIcons.fileText;
    case 'image':
    case 'photo':
      return LucideIcons.image;
    case 'person':
      return LucideIcons.user;
    case 'org':
    case 'team':
      return LucideIcons.users;
    case 'factual':
      return LucideIcons.bookOpen;
    case 'write':
      return LucideIcons.pencil;
    case 'telegram':
      return LucideIcons.send;
    case 'voice':
      return LucideIcons.mic;
    case 'delegate':
      return LucideIcons.userCheck;
    case 'brain':
      return LucideIcons.brain;
    default:
      return LucideIcons.wrench;
  }
}

/// "12s" / "1m 04s" — a step's elapsed-into-the-turn stamp.
String formatElapsed(int ms) {
  final s = ms ~/ 1000;
  if (s < 60) return '${s}s';
  final m = s ~/ 60;
  final rem = s % 60;
  return '${m}m ${rem.toString().padLeft(2, '0')}s';
}

/// The ordered thought trail — one compact line per step: kind icon, label,
/// and the elapsed stamp. Older steps fade; the newest is full-strength (it's
/// the live "what it's doing now" line while the turn runs).
class TurnTrail extends StatelessWidget {
  const TurnTrail({super.key, required this.steps, this.emphasizeLast = true});

  final List<ThoughtStep> steps;

  /// True on the live trail (the last line is the current step); false on the
  /// persisted record, where every step is equally history.
  final bool emphasizeLast;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final muted = theme.colorScheme.mutedForeground;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Opacity(
            opacity: !emphasizeLast || i == steps.length - 1 ? 1 : 0.55,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child:
                        Icon(iconForStepKind(steps[i].kind), size: 13, color: muted),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(steps[i].label, style: theme.textTheme.muted),
                  ),
                  if (steps[i].elapsedMs != null) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        formatElapsed(steps[i].elapsedMs!),
                        style: theme.textTheme.muted
                            .copyWith(fontSize: 11, color: muted.withValues(alpha: 0.7)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A small tap-to-toggle disclosure: a muted header row with a chevron, and
/// the [child] shown when expanded. Used for the live "Thinking" trace and the
/// persisted "Thought process" record.
class TrailDisclosure extends StatefulWidget {
  const TrailDisclosure({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<TrailDisclosure> createState() => _TrailDisclosureState();
}

class _TrailDisclosureState extends State<TrailDisclosure> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final muted = theme.colorScheme.mutedForeground;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                size: 14,
                color: muted,
              ),
              const SizedBox(width: 4),
              Text(widget.title, style: theme.textTheme.muted),
            ],
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 4),
            child: widget.child,
          ),
      ],
    );
  }
}

/// "4 tool calls · 1 failed" — the deterministic tool tally footer for a
/// finished turn ([ToolStats], persisted) shown under the reply.
class ToolStatsLine extends StatelessWidget {
  const ToolStatsLine({super.key, required this.stats});

  final ToolStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final parts = <String>[
      '${stats.calls} tool ${stats.calls == 1 ? 'call' : 'calls'}',
      if (stats.failed > 0) '${stats.failed} failed',
      if (stats.queued > 0) '${stats.queued} awaiting approval',
    ];
    final style = theme.textTheme.muted.copyWith(fontSize: 11);
    return Text(
      parts.join(' · '),
      style: stats.failed > 0
          ? style.copyWith(color: theme.colorScheme.destructive)
          : style,
    );
  }
}
