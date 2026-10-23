import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/auth/auth_session_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Sign out from a signed-in setup screen (email verify, complete profile,
/// create baby): the way off the flow when Back has nowhere to go or the user
/// is on the wrong account (#418). Routing follows the auth state change.
class OnboardingSignOutButton extends StatelessWidget {
  const OnboardingSignOutButton({super.key});

  Future<void> _signOut(BuildContext context) async {
    await context.read<AuthSessionService>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: TextButton(
        onPressed: () => _signOut(context),
        child: Text(
          l10n.authSignOut,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
