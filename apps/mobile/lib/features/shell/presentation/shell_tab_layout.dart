import 'package:flutter/material.dart';

import 'shell_top_bar.dart';

/// Tab root layout: pinned shell top bar + scrollable body (optional pull-to-refresh).
class ShellTabLayout extends StatelessWidget {
  const ShellTabLayout({
    super.key,
    required this.body,
    this.onRefresh,
  });

  final Widget body;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scrollable = onRefresh != null
        ? RefreshIndicator(onRefresh: onRefresh!, child: body)
        : body;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          shellHomeTopBar(context),
          Expanded(child: scrollable),
        ],
      ),
    );
  }
}
