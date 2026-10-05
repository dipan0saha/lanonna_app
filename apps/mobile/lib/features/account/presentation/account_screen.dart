import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../home/data/home_refresh_signal.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../../core/domain/baby_summary.dart';
import '../../../core/domain/baby_list_subtitle.dart';
import '../../home/domain/app_routes.dart';
import '../../onboarding/domain/onboarding_routes.dart';
import '../../onboarding/presentation/onboarding_coordinator.dart';
import '../data/account_repository.dart';
import 'widgets/account_engagement_stat_row.dart';
import 'widgets/account_profile_card.dart';
import 'widgets/account_storage_card.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  AccountPayload? _payload;
  String? _loadError;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final payload = await context.read<AccountRepository>().fetchAccount();
      setState(() {
        _payload = payload;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loadError = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    // Push token cleanup is handled by PushNotificationService auth listener.
    await context.read<OnboardingCoordinator>().resetOwnerCompletionForSignOut();
    await context.read<AuthRepository>().signOut();
    if (mounted) context.go(OnboardingRoutes.ownerCarousel);
  }

  String _initials(String? name, String? email) {
    final source = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : (email ?? 'A');
    final parts = source.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return source[0].toUpperCase();
  }

  String _babySubtitle(BabySummary baby) => babyListSubtitle(baby);

  Color _roleBadgeColor(String role) {
    return role == 'owner' ? AppColors.sageTint : AppColors.peachTint;
  }

  Future<void> _openBaby(BabySummary baby) async {
    await context.read<SelectedBabyStore>().setSelectedBabyId(baby.id);
    if (mounted) {
      context.read<HomeRefreshSignal>().notifyBabyContextChanged();
      context.go('/home');
    }
  }

  Future<void> _openManageFollowers() async {
    final owner = await context.read<HomeRepository>().resolveOwnerBaby(
      context.read<SelectedBabyStore>(),
    );
    if (!mounted) return;
    if (owner == null) {
      AppSnackBar.showAlert(context, 'No baby profile you own yet.');
      return;
    }
    context.push('/baby/${owner.id}/followers');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthRepository>().currentUser;
    final payload = _payload;
    final displayName = payload?.displayName ?? user?.email ?? 'Account';
    final email = payload?.email ?? user?.email;
    final showOwnerPrefs = payload?.hasOwnerBaby ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Account')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AccountProfileCard(
                    initials: _initials(payload?.displayName, email),
                    displayName: displayName,
                    email: email,
                    onEdit: () => context.push('/account/edit'),
                    onLogOut: _signOut,
                  ),
                  const SizedBox(height: 16),
                  if (payload != null)
                    AccountEngagementStatRow(stats: payload.engagement),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Baby Profiles', style: context.textStyles.labelLarge),
                      ),
                      TextButton(
                        onPressed: () => context.push('/baby/create'),
                        child: const Text('+ Add New'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final baby in payload?.babies ?? [])
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.peachTint,
                          child: Text(
                            baby.name.isNotEmpty ? baby.name[0].toUpperCase() : '?',
                          ),
                        ),
                        title: Text(baby.name),
                        subtitle: Text(_babySubtitle(baby)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _roleBadgeColor(baby.role),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            baby.role == 'owner' ? 'Owner' : 'Follower',
                            style: context.textStyles.labelSmall,
                          ),
                        ),
                        onTap: () => _openBaby(baby),
                        onLongPress: baby.role == 'owner'
                            ? () => context.push('/baby/${baby.id}/edit')
                            : null,
                      ),
                    ),
                  if (payload?.storageUsage != null) ...[
                    const SizedBox(height: 16),
                    Text('Storage', style: context.textStyles.labelLarge),
                    const SizedBox(height: 8),
                    AccountStorageCard(usage: payload!.storageUsage!),
                  ],
                  const SizedBox(height: 16),
                  Text('Preferences', style: context.textStyles.labelLarge),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('Settings'),
                          subtitle: const Text('Notifications, profile, and help'),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                          onTap: () => context.push('/settings'),
                        ),
                        if (showOwnerPrefs)
                          AppSemantics.button(
                            'account_manage_followers',
                            ListTile(
                              title: const Text('Manage Followers'),
                              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                              onTap: _openManageFollowers,
                            ),
                          ),
                        if (showOwnerPrefs)
                          ListTile(
                            title: const Text('Invite Family'),
                            trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                            onTap: () => context.push(AppRoutes.inviteFamily),
                          ),
                        if (showOwnerPrefs)
                          ListTile(
                            title: const Text('Export baby data'),
                            trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                            onTap: () => context.push('/account/export'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Account', style: context.textStyles.labelLarge),
                  Card(
                    child: ListTile(
                      title: const Text(
                        'Delete account',
                        style: TextStyle(color: AppColors.error),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                      onTap: () => context.push('/account/delete'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
