import 'package:flutter/cupertino.dart'
    show CupertinoSliverRefreshControl, RefreshIndicatorMode;
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// A lazy list that reloads when pulled down, on both platforms.
///
/// The app has no Material, so no `RefreshIndicator`. This is the Cupertino
/// sliver control (a widget, not a design language) with the app's own
/// indicator drawn from theme tokens. Bouncing physics on Android too: the
/// control works by overscroll, and a list shorter than the screen must still
/// be pullable, hence `AlwaysScrollable`.
///
/// A refresh that fails (its future throws) says so where the pull was,
/// instead of "Up to date".
class PullToRefreshList extends StatefulWidget {
  const PullToRefreshList({
    super.key,
    required this.onRefresh,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.storageKey,
  });

  final Future<void> Function() onRefresh;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ScrollController? controller;
  final EdgeInsets padding;

  /// Keeps the scroll position when the same list comes back (going up a
  /// folder shows it where it was left).
  final Key? storageKey;

  @override
  State<PullToRefreshList> createState() => _PullToRefreshListState();
}

class _PullToRefreshListState extends State<PullToRefreshList> {
  bool _failed = false;

  Future<void> _refresh() async {
    try {
      await widget.onRefresh();
      _failed = false;
    } catch (_) {
      _failed = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: widget.storageKey,
      controller: widget.controller,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: _refresh,
          builder: _indicator,
        ),
        SliverPadding(
          padding: widget.padding,
          sliver: SliverList.builder(
            itemCount: widget.itemCount,
            itemBuilder: widget.itemBuilder,
          ),
        ),
      ],
    );
  }

  Widget _indicator(
    BuildContext context,
    RefreshIndicatorMode mode,
    double pulledExtent,
    double refreshTriggerPullDistance,
    double refreshIndicatorExtent,
  ) {
    final theme = ShadTheme.of(context);
    final pulled =
        (pulledExtent / refreshTriggerPullDistance).clamp(0.0, 1.0);
    final label = switch (mode) {
      RefreshIndicatorMode.drag => 'Pull to refresh',
      RefreshIndicatorMode.armed || RefreshIndicatorMode.refresh => 'Refreshing…',
      RefreshIndicatorMode.done =>
        _failed ? "Couldn't refresh. Pull to try again." : 'Up to date',
      RefreshIndicatorMode.inactive => '',
    };
    return Center(
      child: Opacity(
        opacity: mode == RefreshIndicatorMode.drag ? pulled : 1,
        child: Semantics(
          liveRegion: true,
          child: Text(label, style: theme.textTheme.muted),
        ),
      ),
    );
  }
}
