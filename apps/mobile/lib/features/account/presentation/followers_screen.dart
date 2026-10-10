import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/api/run_mutation.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_bordered_surface.dart';
import '../../../core/widgets/app_section_title.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
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
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<AccountRepository>();
    final members = await repo.listMembers(widget.babyId);
    final invites = await repo.listInvitations(widget.babyId);
    setState(() {
      _members = members;
      _invites = invites.where((i) => i.status == 'pending').toList();
      _loading = false;
    });
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
    final count = _members.where((m) => m.role == 'follower').length;
    return AppSemantics.container(
      'followers_screen',
      PrototypeSubpageScaffold(
        title: 'Manage followers',
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: AppMetrics.subpageScrollPadding,
                children: [
                  Text(
                    '${count} follower${count == 1 ? '' : 's'}',
                    style: context.textStyles.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (_members.isEmpty && _invites.isEmpty)
                    const Text('No followers yet - invite family to join.'),
                  for (final m in _members)
                    AppBorderedSurface(
                      child: ListTile(
                        title: Text(m.displayName),
                        subtitle: Text(m.relationshipLabel ?? m.email ?? m.role),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(label: Text(m.role)),
                            if (m.canRemove)
                              IconButton(
                                icon: const Icon(Icons.person_remove_outlined),
                                tooltip: l10n.memberRemoveAction,
                                onPressed: () => _confirmRemove(m),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (_invites.isNotEmpty) ...[
                    const SizedBox(height: AppMetrics.sectionBlockSpacing),
                    const AppSectionTitle(title: 'Pending invites'),
                    for (final inv in _invites)
                      ListTile(
                        title: Text(inv.email),
                        subtitle: Text(inv.status),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () async {
                            try {
                              await context
                                  .read<AccountRepository>()
                                  .revokeInvitation(widget.babyId, inv.id);
                              await _load();
                            } catch (e) {
                              if (!context.mounted) return;
                              AppSnackBar.showAlert(
                                context,
                                apiErrorMessage(e),
                              );
                            }
                          },
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  Center(
                    child: AppSemantics.button(
                      'followers_invite_more',
                      TextButton(
                        onPressed: () => context.push(AppRoutes.inviteFamily),
                        child: const Text('+ Invite more people'),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
