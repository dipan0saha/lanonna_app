import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/api/run_mutation.dart';
import '../../../core/domain/baby_summary.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/time/app_date_time.dart';
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
      final baby = await homeRepo.babyById(widget.babyId);
      if (!mounted) return;
      setState(() {
        _members = members;
        _invites = invites.where((i) => i.status == 'pending').toList();
        _baby = baby;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  String _inviteTitle(InvitationRow inv) {
    final label = inv.relationshipLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    return 'Pending invite';
  }

  String _inviteSubtitle(InvitationRow inv) {
    if (inv.emailDeliveryStatus == 'failed') {
      return inv.emailLastError ?? 'Email failed to send';
    }
    if (inv.emailDeliveryStatus == 'sent') {
      return 'Invite email sent';
    }
    if (inv.emailDeliveryStatus == 'pending') {
      return 'Pending — email sending';
    }
    return inv.email;
  }

  String? _acceptedLabel(MemberRow member) {
    final raw = member.joinedAt;
    if (raw == null || raw.isEmpty) return null;
    final formatted = formatApiCalendarDate(
      raw,
      localeNameForFormatting(context),
    );
    if (formatted.isEmpty) return 'Accepted';
    return 'Accepted · $formatted';
  }

  Future<void> _confirmRemove(MemberRow member) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.memberRemoveConfirmTitle),
        content: Text(l10n.memberRemoveConfirmBody(member.displayName)),
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
    final followers =
        _members.where((m) => m.role == 'follower').toList(growable: false);
    final count = followers.length;
    final babyName = _baby?.name ?? 'Baby';

    return AppSemantics.container(
      'followers_screen',
      PrototypeSubpageScaffold(
        title: 'Manage followers',
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
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Retry'),
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
                  const SizedBox(height: 16),
                  if (followers.isEmpty && _invites.isEmpty)
                    const Text('No followers yet — invite family to join.'),
                  for (final m in followers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppBorderedSurface(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('👤', style: TextStyle(fontSize: 22)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.displayName,
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
                                TextButton(
                                  onPressed: () => _confirmRemove(m),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                  ),
                                  child: const Text('Revoke'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_invites.isNotEmpty) ...[
                    const SizedBox(height: AppMetrics.sectionBlockSpacing),
                    const AppSectionTitle(title: 'Pending invites'),
                    for (final inv in _invites)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppBorderedSurface(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('✉️', style: TextStyle(fontSize: 20)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                      if (inv.email.isNotEmpty)
                                        Text(
                                          inv.email,
                                          style: context.textStyles.bodySmall,
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (inv.canResendEmail)
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
                                            'Invite email queued',
                                          );
                                          await _load();
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              AppColors.primaryDark,
                                        ),
                                        child: const Text('Resend'),
                                      ),
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
                                            apiErrorMessage(e),
                                          );
                                        }
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                      ),
                                      child: const Text('Revoke'),
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
                      label: '+ Invite more people',
                      onPressed: () => context.push(AppRoutes.inviteFamily),
                    ),
                    label: 'Invite more people',
                  ),
                ],
              ),
      ),
    );
  }
}
