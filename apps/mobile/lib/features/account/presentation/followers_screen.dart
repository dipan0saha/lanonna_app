import 'package:flutter/material.dart';
import 'package:lanonna/core/domain/baby_display_label.dart';
import 'package:lanonna/core/domain/person_display_label.dart';
import 'package:lanonna/features/invitations/domain/invitation_status.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/api/run_mutation.dart';
import '../../../core/domain/baby_summary.dart';
import '../../../core/domain/relationship_preset.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/time/app_date_time.dart';
import '../../../core/widgets/tinted_icon_square.dart';
import '../../../core/widgets/app_bordered_surface.dart';
import '../../../core/widgets/app_section_title.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/dashed_outline_button.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../home/data/home_repository.dart';
import '../../home/domain/app_routes.dart';
import '../data/account_repository.dart';

class FollowersScreen extends StatefulWidget {
  const FollowersScreen({super.key, required this.babyId});

  final String babyId;

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  List<MemberRow> _members = [];
  List<InvitationRow> _invites = [];
  BabySummary? _baby;
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
      final repo = context.read<AccountRepository>();
      final homeRepo = context.read<HomeRepository>();
      final members = await repo.listMembers(widget.babyId);
      final invites = await repo.listInvitations(widget.babyId);
      // Baby name is header copy only; members/invites still render if it fails.
      final baby = await homeRepo
          .babyById(widget.babyId)
          .catchError((Object _) => null);
      if (!mounted) return;
      setState(() {
        _members = members;
        _invites = invites.where((i) => i.status == InvitationStatus.pending).toList();
        _baby = baby;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = apiErrorMessage(AppLocalizations.of(context)!, e);
        _loading = false;
      });
    }
  }

  String _inviteTitle(InvitationRow inv) {
    final l10n = AppLocalizations.of(context)!;
    return relationshipDisplayLabel(l10n, inv.relationshipLabel) ??
        l10n.accountPendingInvite;
  }

  String _inviteSubtitle(InvitationRow inv) {
    final l10n = AppLocalizations.of(context)!;
    // The worker's email_last_error is diagnostic text; users see the status.
    return inv.emailDeliveryStatus?.label(l10n) ?? inv.email;
  }

  String? _acceptedLabel(MemberRow member) {
    final raw = member.joinedAt;
    if (raw == null || raw.isEmpty) return null;
    final formatted = formatApiCalendarDate(
      raw,
      localeNameForFormatting(context),
    );
    if (formatted.isEmpty) return AppLocalizations.of(context)!.invitationStatusAccepted;
    return AppLocalizations.of(context)!.accountAccepted(formatted);
  }

  Future<void> _confirmRemove(MemberRow member) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.memberRemoveConfirmTitle),
        content: Text(l10n.memberRemoveConfirmBody(personDisplayName(l10n, member.displayName))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.authPasswordResetCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.memberRemoveAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final removed = await runMutation(
      context,
      () => context.read<AccountRepository>().removeMember(
        widget.babyId,
        member.firebaseUid,
      ),
    );
    if (!removed || !mounted) return;
    AppSnackBar.showInfo(context, l10n.memberRemovedSuccess);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final followers = _members
        .where((m) => m.role == 'follower')
        .toList(growable: false);
    final count = followers.length;
    final babyName = babyNameLabel(l10n, _baby?.name);

    return AppSemantics.container(
      'followers_screen',
      PrototypeSubpageScaffold(
        title: l10n.actionManageFollowers,
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
                      FilledButton(
                        onPressed: _load,
                        child: Text(AppLocalizations.of(context)!.actionRetry),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: AppMetrics.subpageScrollPadding,
                children: [
                  Text(
                    '$babyName · ${l10n.followerCount(count)}',
                    style: context.textStyles.titleSmall,
                  ),
                  SizedBox(height: AppSpacing.lg),
                  if (followers.isEmpty && _invites.isEmpty)
                    Text(AppLocalizations.of(context)!.followersEmpty),
                  for (final m in followers)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppMetrics.listRowBottomGap,
                      ),
                      child: AppBorderedSurface(
                        child: Padding(
                          padding: AppMetrics.borderedListRowPadding,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const TintedIconSquare(
                                icon: Icons.person_outline,
                              ),
                              SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      personDisplayName(
                                        AppLocalizations.of(context)!,
                                        m.displayName,
                                      ),
                                      style: context.textStyles.titleSmall,
                                    ),
                                    if (_acceptedLabel(m) != null)
                                      Text(
                                        _acceptedLabel(m)!,
                                        style: context.textStyles.bodySmall
                                            ?.copyWith(color: AppColors.muted),
                                      ),
                                  ],
                                ),
                              ),
                              if (m.canRemove)
                                AppSemantics.button(
                                  'member_remove_${m.firebaseUid}',
                                  TextButton(
                                    onPressed: () => _confirmRemove(m),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                    ),
                                    child: Text(AppLocalizations.of(context)!.actionRevoke),
                                  ),
                                  label: l10n.memberRemoveAction,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_invites.isNotEmpty) ...[
                    const SizedBox(height: AppMetrics.sectionBlockSpacing),
                    AppSectionTitle(title: l10n.labelPendingInvites),
                    for (final inv in _invites)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppMetrics.listRowBottomGap,
                        ),
                        child: AppBorderedSurface(
                          child: Padding(
                            padding: AppMetrics.borderedListRowPadding,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const TintedIconSquare(
                                  icon: Icons.mail_outline,
                                ),
                                SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _inviteTitle(inv),
                                        style: context.textStyles.titleSmall,
                                      ),
                                      Text(
                                        _inviteSubtitle(inv),
                                        style: context.textStyles.bodySmall
                                            ?.copyWith(color: AppColors.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (inv.canResendEmail)
                                      AppSemantics.button(
                                        'resend_invite_${inv.id}',
                                        TextButton(
                                          onPressed: () async {
                                            final sent = await runMutation(
                                              context,
                                              () => context
                                                  .read<AccountRepository>()
                                                  .resendInvitation(
                                                    widget.babyId,
                                                    inv.id,
                                                  ),
                                            );
                                            if (!sent || !mounted) return;
                                            AppSnackBar.showInfo(
                                              context,
                                              AppLocalizations.of(context)!.accountInviteEmailQueued,
                                            );
                                            await _load();
                                          },
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                AppColors.primaryDark,
                                          ),
                                          child: Text(AppLocalizations.of(context)!.actionResend),
                                        ),
                                        label: l10n.actionResendInvitation,
                                      ),
                                    AppSemantics.button(
                                      'revoke_invite_${inv.id}',
                                      TextButton(
                                        onPressed: () async {
                                          try {
                                            await context
                                                .read<AccountRepository>()
                                                .revokeInvitation(
                                                  widget.babyId,
                                                  inv.id,
                                                );
                                            await _load();
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            AppSnackBar.showAlert(
                                              context,
                                              apiErrorMessage(AppLocalizations.of(context)!, e),
                                            );
                                          }
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                        ),
                                        child: Text(AppLocalizations.of(context)!.actionRevoke),
                                      ),
                                      label: l10n.actionRevokeInvitation,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  AppSemantics.button(
                    'followers_invite_more',
                    DashedOutlineButton(
                      label: l10n.actionInviteMorePeople,
                      onPressed: () => context.push(AppRoutes.inviteFamily),
                    ),
                    label: l10n.actionInviteMorePeople2,
                  ),
                ],
              ),
      ),
    );
  }
}
