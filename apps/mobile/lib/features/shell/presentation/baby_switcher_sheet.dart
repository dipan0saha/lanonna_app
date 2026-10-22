import 'package:flutter/material.dart';
import 'package:lanonna/core/domain/baby_display_label.dart';

import '../../../core/theme/app_metrics.dart';

import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_modal_sheet.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/widgets/baby_profile_avatar.dart';
import '../../../core/widgets/membership_role_pill.dart';
import '../../../core/api/api_error_message.dart';
import '../../../core/api/run_mutation.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../account/data/account_repository.dart';
import '../../baby/presentation/delete_baby_profile_flow.dart';
import '../../home/data/home_refresh_signal.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../../core/domain/baby_summary.dart';
import '../../../core/domain/baby_list_subtitle.dart';
import '../../../core/time/app_date_time.dart';

Future<void> showBabySwitcherSheet(BuildContext context) async {
  await presentAppModalSheet<void>(
    context: context,
    builder: (ctx) => const _BabySwitcherSheetBody(),
  );
}

class _BabySwitcherSheetBody extends StatefulWidget {
  const _BabySwitcherSheetBody();

  @override
  State<_BabySwitcherSheetBody> createState() => _BabySwitcherSheetBodyState();
}

class _BabySwitcherSheetBodyState extends State<_BabySwitcherSheetBody> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  List<BabySummary> _babies = [];
  String? _highlightedId;
  var _loading = true;
  String? _loadError;

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
      final homeRepo = context.read<HomeRepository>();
      final store = context.read<SelectedBabyStore>();
      final babies = await homeRepo.listBabies();
      final resolved = await homeRepo.resolveSelectedBaby(store);
      if (!mounted) return;
      setState(() {
        _babies = babies;
        _highlightedId = resolved?.id;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = apiErrorMessage(AppLocalizations.of(context)!, e);
      });
    }
  }

  Future<void> _leaveBaby(BabySummary baby) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showConfirmDialog(
      context,
      title: l10n.memberLeaveConfirmTitle,
      message: l10n.memberLeaveConfirmBody,
      confirmLabel: l10n.memberLeaveAction,
    );
    if (ok != true || !mounted) return;
    final left = await runMutation(
      context,
      () => context.read<AccountRepository>().leaveBaby(baby.id),
    );
    if (!left || !mounted) return;
    AppSnackBar.showInfo(context, l10n.memberLeftSuccess);
    final store = context.read<SelectedBabyStore>();
    final homeRepo = context.read<HomeRepository>();
    await homeRepo.resolveSelectedBaby(store);
    if (mounted) {
      context.read<HomeRefreshSignal>().notifyBabyContextChanged();
      Navigator.of(context).pop();
      context.go('/home');
    }
  }

  String _switcherSubtitle(List<BabySummary> babies) {
    final owners = babies.where((b) => b.role == 'owner').length;
    final followers = babies.where((b) => b.role == 'follower').length;
    if (owners > 0 && followers > 0) {
      return l10n.shellYoureTheOwnerOfOne;
    }
    if (owners > 1) {
      return l10n.shellChooseWhichBabyProfileTo;
    }
    return l10n.shellChooseWhichBabyProfileTo;
  }

  Future<void> _select(BabySummary baby) async {
    await context.read<SelectedBabyStore>().setSelectedBabyId(baby.id);
    if (mounted) {
      context.read<HomeRefreshSignal>().notifyBabyContextChanged();
      Navigator.of(context).pop();
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = _highlightedId;

    return AppModalSheet(
      title: l10n.babySwitcherSwitchProfile,
      subtitle: _switcherSubtitle(_babies),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadError != null)
              Column(
                children: [
                  Text(_loadError!, textAlign: TextAlign.center),
                  SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: _load,
                    child: Text(AppLocalizations.of(context)!.actionRetry),
                  ),
                ],
              )
            else if (_babies.isEmpty)
              Text(AppLocalizations.of(context)!.babySwitcherEmpty)
            else
              for (final baby in _babies)
                AppSemantics.button(
                  'baby_switcher_${baby.id.replaceAll('-', '_')}',
                  ListTile(
                    leading: BabyProfileAvatar(baby: baby),
                    title: Text(babyNameLabel(AppLocalizations.of(context)!, baby.name)),
                    subtitle: Text(
                      babyListSubtitle(
        AppLocalizations.of(context)!,
        baby,
        localeNameForFormatting(context),
      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MembershipRolePill(isOwner: baby.role == 'owner'),
                        SizedBox(width: AppSpacing.xs),
                        if (baby.id == selectedId)
                          const Icon(Icons.check, color: AppColors.primaryDark),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            size: AppMetrics.trailingIconSize,
                          ),
                          onSelected: (value) async {
                            if (value == 'leave') {
                              await _leaveBaby(baby);
                              return;
                            }
                            if (value == 'delete') {
                              final deleted =
                                  await deleteBabyProfileWithConfirmation(
                                    context,
                                    baby,
                                  );
                              if (deleted && context.mounted) {
                                Navigator.of(context).pop();
                              }
                              return;
                            }
                            Navigator.of(context).pop();
                            if (value == 'edit') {
                              context.push('/baby/${baby.id}/edit');
                            } else if (value == 'followers') {
                              context.push('/baby/${baby.id}/followers');
                            }
                          },
                          itemBuilder: (ctx) {
                            final l10n = AppLocalizations.of(ctx)!;
                            return [
                              if (baby.role == 'owner') ...[
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(AppLocalizations.of(context)!.babySwitcherEditBaby),
                                ),
                                PopupMenuItem(
                                  value: 'followers',
                                  child: Text(AppLocalizations.of(context)!.actionManageFollowers),
                                ),
                              ],
                              if (baby.canDeleteProfile)
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    AppLocalizations.of(context)!
                                        .deleteBabyProfileAction,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                    ),
                                  ),
                                )
                              else
                                PopupMenuItem(
                                  value: 'leave',
                                  child: Text(l10n.memberLeaveProfile),
                                ),
                            ];
                          },
                        ),
                      ],
                    ),
                    onTap: () => _select(baby),
                  ),
                ),
            const Divider(height: AppSpacing.xxl),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(AppLocalizations.of(context)!.babySwitcherMyAccount),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(AppLocalizations.of(context)!.babySwitcherAddBaby),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/baby/create');
              },
            ),
          ],
        ),
      ),
    );
  }
}
