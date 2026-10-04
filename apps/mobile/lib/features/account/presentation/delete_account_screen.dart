import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/la_nonna_theme.dart';
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

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await context.read<AccountRepository>().deleteAccount();
      await context.read<AuthRepository>().signOut();
      if (mounted) context.go(OnboardingRoutes.ownerCarousel);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PrototypeSubpageScaffold(
      includeShellTopBar: true,
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
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: _deleting ? null : _delete,
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
