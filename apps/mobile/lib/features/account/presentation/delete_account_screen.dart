import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../onboarding/domain/onboarding_routes.dart';
import '../data/account_repository.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  var _deleting = false;
  var _checkingEligibility = true;
  DeleteAccountEligibility? _eligibility;
  String? _eligibilityError;

  @override
  void initState() {
    super.initState();
    _loadEligibility();
  }

  Future<void> _loadEligibility() async {
    setState(() {
      _checkingEligibility = true;
      _eligibilityError = null;
    });
    try {
      final eligibility =
          await context.read<AccountRepository>().fetchDeleteAccountEligibility();
      if (mounted) {
        setState(() {
          _eligibility = eligibility;
          _checkingEligibility = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _eligibilityError = apiErrorMessage(e);
          _checkingEligibility = false;
        });
      }
    }
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await context.read<AccountRepository>().deleteAccount();
      await context.read<AuthRepository>().signOut();
      if (mounted) context.go(OnboardingRoutes.ownerCarousel);
    } catch (e) {
      if (mounted) {
        AppSnackBar.showAlert(context, apiErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final allowed = _eligibility?.allowed ?? false;
    final blockers = _eligibility?.blockers ?? const [];
    final canDelete = allowed && !_checkingEligibility && _eligibilityError == null;

    return PrototypeSubpageScaffold(
      title: l10n.deleteAccountTitle,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.deleteAccountBody,
              style: context.textStyles.bodyMedium,
            ),
            if (_checkingEligibility) ...[
              const SizedBox(height: 24),
              Text(
                l10n.deleteAccountChecking,
                style: context.textStyles.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
            if (_eligibilityError != null) ...[
              const SizedBox(height: 16),
              Text(
                _eligibilityError!,
                style: context.textStyles.bodySmall?.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
            if (!allowed && blockers.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                l10n.deleteAccountBlocked,
                style: context.textStyles.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              for (final blocker in blockers)
                Text(
                  '• $blocker',
                  style: context.textStyles.bodySmall,
                ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: (_deleting || !canDelete) ? null : _delete,
              child: Text(
                _deleting ? l10n.deleteAccountDeleting : l10n.deleteAccountButton,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
