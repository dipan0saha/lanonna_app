import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Blocking load error with Try again, shared by tab bodies and detail
/// screens. A real "not found" is handled by the caller, never shown here.
class AppLoadErrorPane extends StatelessWidget {
  const AppLoadErrorPane({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryButtonKey = const Key('load_error_retry'),
  });

  final String message;
  final VoidCallback onRetry;
  final Key retryButtonKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              key: retryButtonKey,
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context)!.actionTryAgain),
            ),
          ],
        ),
      ),
    );
  }
}
