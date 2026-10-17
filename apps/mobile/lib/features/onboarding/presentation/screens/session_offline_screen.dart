import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/async_tab_body.dart';
import '../app_session.dart';

/// Signed-in cold start when onboarding status could not be loaded and
/// there is no cached server status. Not an onboarding step.
class SessionOfflineScreen extends StatelessWidget {
  const SessionOfflineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    return Scaffold(
      body: AsyncTabBody(
        loading: session.isLoading,
        error: AppLocalizations.of(context)!.errorOffline,
        onRetry: session.refreshFromApi,
        child: const SizedBox.shrink(),
      ),
    );
  }
}
