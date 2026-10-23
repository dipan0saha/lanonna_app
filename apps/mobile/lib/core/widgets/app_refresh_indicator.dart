import 'package:flutter/material.dart';

import '../presentation/tab_load_failure.dart';

/// The app's only pull-to-refresh (raw [RefreshIndicator] is blocked by
/// `scripts/check-no-raw-refresh-indicator.sh`).
///
/// A refresh must never fail silently (#421). Screens report their own load
/// failures with [reportTabLoadFailure] / [reportRefreshFailure] and keep
/// cached content; anything [onRefresh] still throws is reported here, so the
/// spinner always ends with either new content or a message.
class AppRefreshIndicator extends StatelessWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        try {
          await onRefresh();
        } catch (error) {
          if (context.mounted) reportRefreshFailure(context, error);
        }
      },
      child: child,
    );
  }
}
