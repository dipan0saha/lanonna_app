import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/session_cleanup.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_bordered_surface.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/widgets/app_section_title.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../home/data/home_refresh_signal.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../../core/domain/baby_summary.dart';
import '../../../core/domain/baby_list_subtitle.dart';
import '../../../core/time/app_date_time.dart';
import '../../home/domain/app_routes.dart';
import '../../onboarding/domain/onboarding_routes.dart';
import '../data/account_repository.dart';
import '../data/notifications_repository.dart';
import '../domain/notification_digest_display.dart';
import 'widgets/account_engagement_stat_row.dart';
import 'widgets/account_baby_profiles_card.dart';
import 'widgets/account_profile_card.dart';
import 'widgets/account_storage_card.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  AccountPayload? _payload;
  String? _digestSummary;
  String? _loadError;
  var _loading = true;
  AccountProfileUpdates? _profileUpdates;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final updates = context.read<AccountRepository>().profileUpdates;
    if (!identical(_profileUpdates, updates)) {
      _profileUpdates?.removeListener(_onAccountUpdated);
      _profileUpdates = updates;
      _profileUpdates!.addListener(_onAccountUpdated);
    }
  }

  @override
  void dispose() {
    _profileUpdates?.removeListener(_onAccountUpdated);
    super.dispose();
  }

  void _onAccountUpdated() {
    final cached = _profileUpdates?.account;
    if (!mounted || cached == null) return;
    setState(() {
      _payload = cached;
      _loading = false;
      _loadError = null;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final notificationsRepo = context.read<NotificationsRepository>();
    try {
      final payload = await context.read<AccountRepository>().fetchAccount();
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = apiErrorMessage(e);
        _loading = false;
      });
      return;
    }
    await _loadDigestSummary(notificationsRepo);
  }

  /// Best-effort: the digest row is secondary, so a preferences failure hides
  /// the row instead of failing the whole Account screen.
  Future<void> _loadDigestSummary(NotificationsRepository repo) async {
    try {
      final prefs = await repo.fetchPreferences();
      if (!mounted) return;
      setState(() {
        _digestSummary = notificationDigestSummaryLabel(prefs.digest);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _digestSummary = null);
    }
  }

  Future<void> _signOut() async {
    // Push token cleanup is handled by PushNotificationService auth listener.
    await context.read<SessionCleanup>().clearLocalUserData();
    if (!mounted) return;
    await context.read<AuthRepository>().signOut();
    if (mounted) context.go(OnboardingRoutes.ownerCarousel);
  }

  String _babySubtitle(BabySummary baby) =>
      babyListSubtitle(baby, localeNameForFormatting(context));

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
    final l10n = AppLocalizations.of(context)!;

    return PrototypeSubpageScaffold(
      title: 'My Account',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
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
                padding: AppMetrics.subpageScrollPadding,
                children: [
                  AccountProfileCard(
                    displayName: displayName,
                    email: email,
                    avatarUrl: payload?.avatarUrl,
                    onEdit: () => context.push('/account/edit'),
                    onLogOut: _signOut,
                  ),
                  const SizedBox(height: 16),
                  if (payload != null)
                    AccountEngagementStatRow(stats: payload.engagement),
                  const SizedBox(height: 20),
                  AppSectionTitle(
                    title: 'Baby Profiles',
                    action: TextButton(
                      onPressed: () => context.push('/baby/create'),
                      child: const Text('+ Add New'),
                    ),
                  ),
                  AccountBabyProfilesCard(
                    babies: payload?.babies ?? [],
                    subtitleFor: _babySubtitle,
                    onBabyTap: _openBaby,
                    onBabyLongPress: (baby) {
                      if (baby.role == 'owner') {
                        context.push('/baby/${baby.id}/edit');
                      }
                    },
                  ),
                  if (payload?.storageUsage != null) ...[
                    const SizedBox(height: AppMetrics.sectionBlockSpacing),
                    const AppSectionTitle(title: 'Storage'),
                    AccountStorageCard(usage: payload!.storageUsage!),
                  ],
                  const SizedBox(height: AppMetrics.sectionBlockSpacing),
                  const AppSectionTitle(title: 'Preferences'),
                  AppBorderedSurface(
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('Settings'),
                          subtitle: const Text(
                            'Notifications, profile, and help',
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.muted,
                          ),
                          onTap: () => context.push('/settings'),
                        ),
                        if (_digestSummary != null)
                          AppSemantics.button(
                            'account_digest_frequency',
                            ListTile(
                              title: Text(l10n.accountDigestFrequency),
                              subtitle: Text(_digestSummary!),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: AppColors.muted,
                              ),
                              onTap: () async {
                                await context.push(
                                  '/account/notification-preferences',
                                );
                                if (!mounted) return;
                                await _load();
                              },
                            ),
                            label: '${l10n.accountDigestFrequency}, $_digestSummary',
                          ),
                        if (showOwnerPrefs)
                          AppSemantics.button(
                            'account_manage_followers',
                            ListTile(
                              title: const Text('Manage Followers'),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: AppColors.muted,
                              ),
                              onTap: _openManageFollowers,
                            ),
                          ),
                        if (showOwnerPrefs)
                          ListTile(
                            title: const Text('Invite Family'),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppColors.muted,
                            ),
                            onTap: () => context.push(AppRoutes.inviteFamily),
                          ),
                        if (showOwnerPrefs)
                          ListTile(
                            title: const Text('Export baby data'),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppColors.muted,
                            ),
                            onTap: () => context.push('/account/export'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppMetrics.sectionBlockSpacing),
                  const AppSectionTitle(title: 'Account'),
                  AppBorderedSurface(
                    child: ListTile(
                      title: const Text(
                        'Delete account',
                        style: TextStyle(color: AppColors.error),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppColors.muted,
                      ),
                      onTap: () => context.push('/account/delete'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
