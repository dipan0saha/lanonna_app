import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../theme/app_metrics.dart';

/// Footer for a paged list: "Load more", or a small spinner while the next
/// page is loading. Lists that also load on scroll keep it as the retry path.
class AppLoadMoreButton extends StatelessWidget {
  const AppLoadMoreButton({
    super.key,
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback onPressed;

  static const double _spinnerSize = 20;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppMetrics.listRowBottomGap),
      child: Center(
        child: TextButton(
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox.square(
                  dimension: _spinnerSize,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context)!.actionLoadMore),
        ),
      ),
    );
  }
}
