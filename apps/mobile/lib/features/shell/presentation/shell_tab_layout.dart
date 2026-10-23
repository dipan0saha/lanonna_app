import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_refresh_indicator.dart';
import '../../home/data/home_repository.dart';

import 'shell_top_bar.dart';

/// Tab root layout: pinned shell top bar + scrollable body (optional pull-to-refresh).
///
/// Pull-to-refresh also refetches the shared baby list, so a change made by
/// another member (rename, role) shows up on demand.
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
    final refresh = onRefresh;
    final scrollable = refresh != null
        ? AppRefreshIndicator(
            onRefresh: () {
              context.read<HomeRepository>().refreshBabiesOnNextRead();
              return refresh();
            },
            child: body,
          )
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
