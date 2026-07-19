import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/dashboard/dashboard_models.dart';
import '../../widgets/mantle_header.dart';
import '../dashboard/dashboard_controller.dart';

// Status colours for health indicators — semantic states the shadcn palette
// doesn't carry. Used only for the up/down dots and load meters below.
const _healthy = Color(0xFF22C55E);
const _warn = Color(0xFFF59E0B);

/// The landing dashboard: quick actions (chat / pending / settings) and Mantle's
/// headline stats (spend, pending, brain, vectors, server health).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final async = ref.watch(dashboardControllerProvider);
    final pending = async.value?.summary.pendingCount;

    return Container(
      color: theme.colorScheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: const MantleHeaderTitle('mantle'),
            trailing: [
              ShadButton.ghost(
                onPressed: () => context.push('/search'),
                child: Icon(
                  LucideIcons.search,
                  size: 20,
                  color: theme.colorScheme.primaryForeground,
                ),
              ),
              ShadButton.ghost(
                onPressed: () => context.push('/settings'),
                child: Icon(
                  LucideIcons.settings,
                  size: 20,
                  color: theme.colorScheme.primaryForeground,
                ),
              ),
            ],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ActionTile(
                          theme: theme,
                          icon: LucideIcons.messageCircle,
                          label: 'Chat',
                          onTap: () => context.push('/chat'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionTile(
                          theme: theme,
                          icon: LucideIcons.fileText,
                          label: 'Pages',
                          onTap: () => context.push('/pages'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionTile(
                          theme: theme,
                          icon: LucideIcons.stickyNote,
                          label: 'Notes',
                          onTap: () => context.push('/notes'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionTile(
                          theme: theme,
                          icon: LucideIcons.listChecks,
                          label: 'Tasks',
                          onTap: () => context.push('/tasks'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionTile(
                          theme: theme,
                          icon: LucideIcons.notebookPen,
                          label: 'Journal',
                          onTap: () => context.push('/journal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionTile(
                          theme: theme,
                          icon: LucideIcons.calendarClock,
                          label: 'Events',
                          onTap: () => context.push('/events'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionTile(
                          theme: theme,
                          icon: LucideIcons.search,
                          label: 'Search',
                          onTap: () => context.push('/search'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionTile(
                          theme: theme,
                          icon: LucideIcons.inbox,
                          label: 'Pending',
                          badge: pending,
                          onTap: () => context.push('/pending'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionTile(
                          theme: theme,
                          icon: LucideIcons.folder,
                          label: 'Files',
                          onTap: () => context.push('/files'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  async.when(
                    loading: () => Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text('Loading…', style: theme.textTheme.muted),
                      ),
                    ),
                    error: (e, _) => _StatsError(theme: theme, ref: ref),
                    data: (data) => _Stats(theme: theme, data: data),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _grouped(int n) {
  final s = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
    buffer.write(s[i]);
  }
  return buffer.toString();
}

class _Stats extends StatelessWidget {
  const _Stats({required this.theme, required this.data});

  final ShadThemeData theme;
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final s = data.summary;
    final trend = s.spendTrendPct;
    final scheme = theme.colorScheme;
    // IntrinsicHeight bounds each row's height (to the taller card) so the
    // stretched cards equalise — a plain stretched Row in a ListView would get
    // unbounded height and crash.
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  theme: theme,
                  icon: LucideIcons.coins,
                  label: 'Spend · 7d',
                  value: '\$${s.spendLast7Usd.toStringAsFixed(2)}',
                  sub: trend == null
                      ? 'vs prior 7d'
                      : '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(0)}% vs prior',
                  subColor: trend != null && trend > 0
                      ? scheme.mutedForeground
                      : _healthy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  theme: theme,
                  icon: LucideIcons.inbox,
                  label: 'Pending',
                  value: _grouped(s.pendingCount),
                  sub: 'to review',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  theme: theme,
                  icon: LucideIcons.brain,
                  label: 'Brain nodes',
                  value: _grouped(s.brainNodes),
                  sub: '${_grouped(s.entities)} entities',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  theme: theme,
                  icon: LucideIcons.layers,
                  label: 'Vectors',
                  value: _grouped(s.vectorsTotal),
                  sub: 'indexed',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ServerCard(theme: theme, health: data.health),
      ],
    );
  }
}

class _StatsError extends StatelessWidget {
  const _StatsError({required this.theme, required this.ref});

  final ShadThemeData theme;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Text(
            "Couldn't load your dashboard.",
            style: theme.textTheme.muted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ShadButton.outline(
            onPressed: () =>
                ref.read(dashboardControllerProvider.notifier).refresh(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final ShadThemeData theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: scheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.border),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 24, color: scheme.primary),
                if (badge != null && badge! > 0)
                  Positioned(
                    top: -6,
                    right: -12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.destructive,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge! > 99 ? '99+' : '$badge',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.destructiveForeground,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.small.copyWith(color: scheme.foreground),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.theme,
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.subColor,
  });

  final ShadThemeData theme;
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color? subColor;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return ShadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: scheme.mutedForeground),
              const SizedBox(width: 6),
              Text(label, style: theme.textTheme.small),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.h3.copyWith(color: scheme.foreground),
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub!,
              style: theme.textTheme.small.copyWith(
                color: subColor ?? scheme.mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({required this.theme, required this.health});

  final ShadThemeData theme;
  final ServerHealth? health;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final h = health;
    return ShadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.server, size: 15, color: scheme.mutedForeground),
              const SizedBox(width: 6),
              Text('Server', style: theme.textTheme.small),
            ],
          ),
          const SizedBox(height: 12),
          if (h == null)
            Text('Vitals unavailable.', style: theme.textTheme.muted)
          else ...[
            _Meter(theme: theme, label: 'CPU', pct: h.cpuPct),
            _Meter(theme: theme, label: 'RAM', pct: h.memPct),
            _Meter(theme: theme, label: 'Disk', pct: h.diskPct),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _ServiceDot(theme: theme, label: 'Postgres', up: h.postgresUp),
                _ServiceDot(theme: theme, label: 'Embedder', up: h.embedderUp),
                _ServiceDot(theme: theme, label: 'Storage', up: h.minioUp),
                _ServiceDot(theme: theme, label: 'Network', up: h.networkUp),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.theme, required this.label, required this.pct});

  final ShadThemeData theme;
  final String label;
  final double? pct;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final p = pct;
    final fill = p == null
        ? scheme.mutedForeground
        : p >= 90
            ? scheme.destructive
            : p >= 70
                ? _warn
                : _healthy;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(label, style: theme.textTheme.small),
          ),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: scheme.muted,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ((p ?? 0) / 100).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              p == null ? '—' : '${p.round()}%',
              textAlign: TextAlign.right,
              style: theme.textTheme.small,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceDot extends StatelessWidget {
  const _ServiceDot({required this.theme, required this.label, required this.up});

  final ShadThemeData theme;
  final String label;
  final bool? up;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final color = up == null
        ? scheme.mutedForeground
        : up!
            ? _healthy
            : scheme.destructive;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.small),
      ],
    );
  }
}
