import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/agents/agent.dart';
import '../../theme/mantle_theme.dart';
import '../../data/agents/agent_api.dart';

/// A round agent avatar. If the agent has a generated avatar on Mantle, it
/// renders that (boring-avatars SVG, fetched + cached); otherwise — or while it
/// loads — it falls back to initials on a slug-derived accent (matching
/// Mantle's own fallback).
class AgentAvatar extends ConsumerWidget {
  const AgentAvatar({super.key, required this.agent, this.size = 26});

  final Agent agent;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (agent.hasAvatar) {
      final svg = ref.watch(agentAvatarSvgProvider(agent.slug)).value;
      if (svg != null) {
        return ClipOval(
          child: SizedBox(
            width: size,
            height: size,
            child: SvgPicture.string(svg, fit: BoxFit.cover),
          ),
        );
      }
    }
    return _initials();
  }

  Widget _initials() {
    final color = HSLColor.fromAHSL(1, agent.accentHue.toDouble(), 0.58, 0.45)
        .toColor();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      // A generated graphic, not themed text: the fill comes from the slug,
      // so the ink is chosen by luminance and the glyph scales with the
      // circle (the one place a size is not a scale entry).
      child: Text(
        agent.initials,
        style: TextStyle(
          color: MantleColors.inkOn(color),
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}
