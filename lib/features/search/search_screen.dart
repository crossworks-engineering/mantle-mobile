import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/search/search_models.dart';
import '../../core/format/dates.dart';
import '../../widgets/mantle_header.dart';
import 'search_controller.dart';

/// Global brain search (`GET /api/search`): debounced as-you-type query,
/// type filter chips, relevance-ranked results. Node types with an in-app
/// surface deep-link into it; everything else opens a detail sheet with an
/// "Open in Mantle" web link.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

/// Chip row: label → server `type` param (null = all).
const _typeChips = <(String, String?)>[
  ('All', null),
  ('Pages', 'page'),
  ('Notes', 'note'),
  ('Files', 'file'),
  ('Email', 'email'),
  ('Tasks', 'task'),
  ('Events', 'event'),
  ('Journal', 'journal'),
  ('Contacts', 'contact'),
];

IconData _typeIcon(String type) => switch (type) {
      'page' => LucideIcons.fileText,
      'note' => LucideIcons.stickyNote,
      'file' => LucideIcons.file,
      'email' || 'email_thread' => LucideIcons.mail,
      'task' => LucideIcons.listChecks,
      'event' => LucideIcons.calendarClock,
      'journal' => LucideIcons.notebookPen,
      'contact' => LucideIcons.user,
      'telegram_message' => LucideIcons.send,
      'documentation' => LucideIcons.bookOpen,
      _ => LucideIcons.search,
    };

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _open(SearchResult r) {
    switch (r.type) {
      case 'page':
        context.push('/pages/${r.id}');
      case 'note':
        context.push('/notes/${r.id}');
      case 'task':
        context.push('/tasks');
      case 'event':
        context.push('/events');
      case 'journal':
        context.push('/journal');
      default:
        _showDetails(r);
    }
  }

  Future<void> _showDetails(SearchResult r) async {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    await showShadSheet<void>(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (ctx) => ShadSheet(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_typeIcon(r.type), size: 18,
                      color: scheme.mutedForeground),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.title,
                      style: theme.textTheme.h4
                          .copyWith(color: scheme.foreground),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(r.type, style: theme.textTheme.muted),
              if (r.summary != null && r.summary!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(r.summary!,
                    style: theme.textTheme.p
                        .copyWith(color: scheme.foreground)),
              ],
              const SizedBox(height: 16),
              if (r.url.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ShadButton(
                    onPressed: () async {
                      final uri = Uri.tryParse(r.url);
                      if (uri != null) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: const Text('Open in Mantle'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final fg = scheme.primaryForeground;
    final s = ref.watch(searchControllerProvider);
    final notifier = ref.read(searchControllerProvider.notifier);

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: const MantleHeaderTitle('Search', wordmark: false),
            trailing: [
              ShadButton.ghost(
                onPressed: () => context.pop(),
                child: Icon(LucideIcons.arrowLeft, size: 20, color: fg),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: ShadInput(
              controller: _input,
              autofocus: true,
              placeholder: const Text('Search your brain…'),
              style: theme.textTheme.p,
              onChanged: notifier.onQueryChanged,
              onSubmitted: notifier.searchNow,
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final (label, type) in _typeChips)
                  _FilterChip(
                    theme: theme,
                    label: label,
                    selected: s.type == type,
                    onTap: () => notifier.setType(type),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: _Results(theme: theme, state: s, onOpen: _open),
            ),
          ),
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.theme, required this.state, required this.onOpen});

  final ShadThemeData theme;
  final SearchState state;
  final void Function(SearchResult) onOpen;

  @override
  Widget build(BuildContext context) {
    if (state.error != null) {
      return Center(child: Text(state.error!, style: theme.textTheme.muted));
    }
    if (state.query.length < kSearchMinChars) {
      return Center(
        child: Text('Search pages, notes, files, email — everything.',
            style: theme.textTheme.muted),
      );
    }
    if (state.searching && state.results.isEmpty) {
      return Center(child: Text('Searching…', style: theme.textTheme.muted));
    }
    if (state.searched && state.results.isEmpty) {
      return Center(
        child: Text('No results for "${state.query}".',
            style: theme.textTheme.muted),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        for (final r in state.results)
          _ResultTile(theme: theme, result: r, onTap: () => onOpen(r)),
        if (state.searching)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: Text('Searching…', style: theme.textTheme.muted),
            ),
          ),
      ],
    );
  }
}


class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.theme,
    required this.result,
    required this.onTap,
  });

  final ShadThemeData theme;
  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final muted = scheme.mutedForeground;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 10, 2),
              child: Icon(_typeIcon(result.type), size: 18, color: muted),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.p.copyWith(color: scheme.foreground),
                  ),
                  if (result.summary != null &&
                      result.summary!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      result.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.small.copyWith(color: muted),
                    ),
                  ],
                  if (result.supersededBy != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'superseded — newer copy exists',
                      style: theme.textTheme.small
                          .copyWith(color: scheme.destructive),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (result.updatedAt != null)
              Text(
                formatWhen(result.updatedAt!),
                style: theme.textTheme.small.copyWith(color: muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ShadThemeData theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6, top: 4, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    );
  }
}
