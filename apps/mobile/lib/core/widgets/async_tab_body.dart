import 'package:flutter/material.dart';

import '../presentation/detail_screen_load.dart';

/// Standard loading / error / content switch for tab screens (offline and API errors).
class AsyncTabBody extends StatelessWidget {
  const AsyncTabBody({
    super.key,
    required this.loading,
    required this.onRetry,
    this.error,
    required this.child,
  });

  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && error!.isNotEmpty) {
      return DetailLoadErrorPane(
        message: error!,
        onRetry: onRetry,
        retryButtonKey: const Key('async_tab_retry'),
      );
    }
    return child;
  }
}
