import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/async_tab_body.dart';
import '../app_session.dart';

/// Signed-in session screen while no server onboarding status is known for
/// this account: a spinner while the status loads (e.g. a signed-in cold
/// start with nothing cached), the offline retry when the fetch failed.
/// Redirect leaves it for [AppSession.signedInResumeLocation] as soon as a
/// status exists, so no destination is guessed. Not an onboarding step.
class SessionOfflineScreen extends StatefulWidget {
  const SessionOfflineScreen({super.key});

  @override
  State<SessionOfflineScreen> createState() => _SessionOfflineScreenState();
}

class _SessionOfflineScreenState extends State<SessionOfflineScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = context.read<AppSession>();
      // Nothing in flight and nothing known: start the fetch rather than
      // spin forever.
      if (!session.isLoading &&
          session.statusPhase == OnboardingStatusPhase.unknown) {
        session.refreshFromApi();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final unavailable =
        session.statusPhase == OnboardingStatusPhase.unavailable;
    return Scaffold(
      body: AsyncTabBody(
        loading: session.isLoading || !unavailable,
        error: AppLocalizations.of(context)!.errorOffline,
        onRetry: session.refreshFromApi,
        child: const SizedBox.shrink(),
      ),
    );
  }
}
