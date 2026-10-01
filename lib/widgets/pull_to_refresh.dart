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
class PullToRefreshList extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: storageKey,
      controller: controller,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: onRefresh,
          builder: _indicator,
        ),
        SliverPadding(
          padding: padding,
          sliver: SliverList.builder(
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }

  static Widget _indicator(
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
      RefreshIndicatorMode.done => 'Up to date',
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
