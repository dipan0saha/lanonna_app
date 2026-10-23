import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lanonna/core/domain/baby_display_label.dart';
import 'package:lanonna/core/domain/person_display_label.dart';
import 'package:lanonna/features/invitations/domain/invitation_status.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/presentation/tab_load_failure.dart';
import '../../../core/api/run_mutation.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
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
import '../../invitations/presentation/revoke_invitation_flow.dart';
import '../../../core/data/parallel_requests.dart';

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
  var _hasLoaded = false;
  String? _loadError;
  Future<void>? _loadRun;
  var _reloadRequested = false;
  Timer? _inviteDeliveryPoll;
  // Polls left in this delivery window; null when nothing is being sent.
  int? _invitePollsLeft;
  static const _invitePollInterval = Duration(seconds: 2);
  static const _invitePollMaxCount = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inviteDeliveryPoll?.cancel();
    super.dispose();
  }

  /// One load at a time: a reload asked for while one runs (a resend during a
  /// poll) runs right after it, so the list always ends on fresh server state.
  Future<void> _load() {
    final running = _loadRun;
    if (running != null) {
      _reloadRequested = true;
      return running;
    }
    return _loadRun = _runLoads();
  }

  Future<void> _runLoads() async {
    try {
      do {
        _reloadRequested = false;
        await _fetch();
      } while (_reloadRequested && mounted);
    } finally {
      _loadRun = null;
    }
  }

  /// The spinner shows only for the first load; reloads after remove,
  /// resend or revoke keep the list and its scroll position, and a failed
  /// reload is a snackbar.
  Future<void> _fetch() async {
    if (!_hasLoaded) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final repo = context.read<AccountRepository>();
      final homeRepo = context.read<HomeRepository>();
      // Baby name is header copy only; members/invites still render if it fails.
      final (members, invites, baby) = await waitAll3(
        repo.listMembers(widget.babyId),
        repo.listInvitations(widget.babyId),
        homeRepo.babyById(widget.babyId).then<BabySummary?>(
          (b) => b,
          onError: (Object _) => null,
        ),
      );
      if (!mounted) return;
      setState(() {
        _members = members;
        _invites = invites.where((i) => i.status == InvitationStatus.pending).toList();
        _baby = baby;
        _loading = false;
        _hasLoaded = true;
      });
      _scheduleDeliveryPoll();
    } catch (e) {
      if (!mounted) return;
      reportTabLoadFailure(
        context,
        e,
        hasPayload: _hasLoaded,
        onBlockingError: (message) => setState(() {
          _loadError = message;
          _loading = false;
        }),
      );
    }
  }

  /// While an invite email is being sent, reload once [_invitePollInterval]
  /// after each load, at most [_invitePollMaxCount] times per window (#410).
  /// The server's `can_resend_email` ends a stuck send, so this always stops.
  void _scheduleDeliveryPoll() {
    _inviteDeliveryPoll?.cancel();
    _inviteDeliveryPoll = null;
    if (!_invites.any((i) => i.emailDeliveryInFlight)) {
      _invitePollsLeft = null;
      return;
    }
    final left = _invitePollsLeft ?? _invitePollMaxCount;
    if (left <= 0) return;
    _invitePollsLeft = left - 1;
    _inviteDeliveryPoll = Timer(_invitePollInterval, _load);
  }

  Future<void> _resendInvite(InvitationRow inv) async {
    final queued = await runMutation(
      context,
      () => context.read<AccountRepository>().resendInvitation(widget.babyId, inv.id),
    );
    if (!mounted) return;
    if (queued) {
      AppSnackBar.showInfo(
        context,
        AppLocalizations.of(context)!.accountInviteEmailQueued,
      );
      // A new send: watch it for a full window.
      _invitePollsLeft = null;
    }
    // Queued or refused (already delivered, revoked): show what the server has.
    await _load();
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
    final ok = await showConfirmDialog(
      context,
      title: l10n.memberRemoveConfirmTitle,
      message: l10n.memberRemoveConfirmBody(
        personDisplayName(l10n, member.displayName),
      ),
      confirmLabel: l10n.memberRemoveAction,
      variant: ConfirmDialogVariant.destructive,
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
    setState(() {
      _members = [
        for (final m in _members)
          if (m.firebaseUid != member.firebaseUid) m,
      ];
    });
    AppSnackBar.showInfo(context, l10n.memberRemovedSuccess);
    await _load();
  }

  Future<void> _confirmRevokeInvite(InvitationRow inv) async {
    final revoked = await revokeInvitationWithConfirmation(
      context,
      babyId: widget.babyId,
      invitationId: inv.id,
      inviteeEmail: inv.email,
    );
    if (!revoked || !mounted) return;
    setState(() {
      _invites = [
        for (final i in _invites)
          if (i.id != inv.id) i,
      ];
    });
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
                                    child: Text(l10n.memberRemoveAction),
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
                                          onPressed: () => _resendInvite(inv),
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
                                        onPressed: () => _confirmRevokeInvite(inv),
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
