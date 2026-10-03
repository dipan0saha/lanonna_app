import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  DeleteAccountEligibility? _eligibility;
  var _loading = true;
  var _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await context.read<AccountRepository>().deleteAccountEligibility();
    setState(() {
      _eligibility = e;
      _loading = false;
    });
  }

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
    final e = _eligibility;
    return PrototypeSubpageScaffold(
      includeShellTopBar: true,
      title: 'Delete account',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading || e == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'This permanently deletes your La Nonna account and signs you out.',
                    style: context.textStyles.bodyMedium,
                  ),
                  if (!e.allowed) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Before you can delete your account:',
                      style: context.textStyles.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    for (final b in e.blockers)
                      Text(
                        '• Transfer or remove sole-owned baby profile (${b.replaceFirst('sole_owner_of_baby:', '')})',
                        style: context.textStyles.bodySmall,
                      ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                    ),
                    onPressed: e.allowed && !_deleting ? _delete : null,
                    child: Text(_deleting ? 'Deleting…' : 'Delete my account'),
                  ),
                ],
              ),
      ),
    );
  }
}
