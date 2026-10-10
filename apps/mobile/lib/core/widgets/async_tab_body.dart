import 'package:flutter/material.dart';

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
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('async_tab_retry'),
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    return child;
  }
}
