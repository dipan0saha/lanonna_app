import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/auth_session_service.dart';
import '../../../core/presentation/tab_load_failure.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_bordered_surface.dart';
import '../../../core/widgets/app_refresh_indicator.dart';
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
    // Pull-to-refresh keeps the account on screen; only the first load spins.
    if (_payload == null) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    // The digest row's preferences load alongside the account, not after it.
    final prefsFuture = context
        .read<NotificationsRepository>()
        .fetchPreferences()
        .then<NotificationPreferences?>((p) => p, onError: (Object _) => null);
    try {
      final payload = await context.read<AccountRepository>().fetchAccount();
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      reportTabLoadFailure(
        context,
        e,
        hasPayload: _payload != null,
        onBlockingError: (message) => setState(() {
          _loadError = message;
          _loading = false;
        }),
      );
      return;
    }
    await _showDigestSummary(prefsFuture);
  }

  /// Best-effort: the digest row is secondary, so a preferences failure
  /// (`null`) hides the row instead of failing the whole Account screen.
  Future<void> _showDigestSummary(
    Future<NotificationPreferences?> prefsFuture,
  ) async {
    final prefs = await prefsFuture;
    if (!mounted) return;
    setState(() {
      _digestSummary = prefs?.digest.summaryLabel(
        AppLocalizations.of(context)!,
      );
    });
  }

  Future<void> _signOut() async {
    await context.read<AuthSessionService>().signOut();
    if (mounted) context.go(OnboardingRoutes.ownerCarousel);
  }

  String _babySubtitle(BabySummary baby) =>
      babyListSubtitle(
        AppLocalizations.of(context)!,
        baby,
        localeNameForFormatting(context),
      );

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
      AppSnackBar.showAlert(context, AppLocalizations.of(context)!.accountNoBabyProfileYouOwn);
      return;
    }
    context.push('/baby/${owner.id}/followers');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthRepository>().currentUser;
    final payload = _payload;
    final displayName = payload?.displayName ?? user?.email ?? AppLocalizations.of(context)!.labelAccount;
    final email = payload?.email ?? user?.email;
    final showOwnerPrefs = payload?.hasOwnerBaby ?? false;
    final l10n = AppLocalizations.of(context)!;

    return PrototypeSubpageScaffold(
      title: l10n.babySwitcherMyAccount,
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: Text(AppLocalizations.of(context)!.actionRetry)),
                  ],
                ),
              ),
            )
          : AppRefreshIndicator(
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
                    title: l10n.labelBabyProfiles,
                    action: TextButton(
                      onPressed: () => context.push('/baby/create'),
                      child: Text(AppLocalizations.of(context)!.accountAddNewBaby),
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
                    AppSectionTitle(title: l10n.labelStorage),
                    AccountStorageCard(usage: payload!.storageUsage!),
                  ],
                  const SizedBox(height: AppMetrics.sectionBlockSpacing),
                  AppSectionTitle(title: l10n.labelPreferences),
                  AppBorderedSurface(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(AppLocalizations.of(context)!.settingsTitle),
                          subtitle: Text(
                            l10n.labelNotificationsProfileHelp,
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
                              title: Text(AppLocalizations.of(context)!.accountManageFollowers),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: AppColors.muted,
                              ),
                              onTap: _openManageFollowers,
                            ),
                          ),
                        if (showOwnerPrefs)
                          ListTile(
                            title: Text(AppLocalizations.of(context)!.accountInviteFamily),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppColors.muted,
                            ),
                            onTap: () => context.push(AppRoutes.inviteFamily),
                          ),
                        if (showOwnerPrefs)
                          ListTile(
                            title: Text(AppLocalizations.of(context)!.accountExportBabyData),
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
                  AppSectionTitle(title: l10n.labelAccount),
                  AppBorderedSurface(
                    child: AppSemantics.button(
                      'account_delete_entry',
                      ListTile(
                        title: Text(
                          l10n.deleteAccountConfirmAction,
                          style: TextStyle(color: AppColors.error),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.muted,
                        ),
                        onTap: () => context.push('/account/delete'),
                      ),
                      label: l10n.deleteAccountConfirmAction,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
