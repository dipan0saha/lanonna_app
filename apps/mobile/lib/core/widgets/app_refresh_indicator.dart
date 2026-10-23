import 'package:flutter/material.dart';

/// App-wide pull-to-refresh wrapper.
///
/// Tab and subpage reloads should report failures with [reportRefreshFailure]
/// while keeping cached content on screen (see [TabLoadKind]).
class AppRefreshIndicator extends StatelessWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.displacement,
    this.edgeOffset,
    this.color,
    this.backgroundColor,
    this.notificationPredicate,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final double? displacement;
  final double? edgeOffset;
  final Color? color;
  final Color? backgroundColor;
  final ScrollNotificationPredicate? notificationPredicate;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      displacement: displacement ?? 40,
      edgeOffset: edgeOffset ?? 0,
      color: color,
      backgroundColor: backgroundColor,
      notificationPredicate:
          notificationPredicate ?? defaultScrollNotificationPredicate,
      child: child,
    );
  }
}
