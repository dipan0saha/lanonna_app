import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_semantics.dart';
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

  @override
  Widget build(BuildContext context) {
    final count = _members.where((m) => m.role == 'follower').length;
    return AppSemantics.container(
      'followers_screen',
      PrototypeSubpageScaffold(
      title: 'Manage followers',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${count} follower${count == 1 ? '' : 's'}',
                  style: context.textStyles.bodySmall,
                ),
                const SizedBox(height: 12),
                if (_members.isEmpty && _invites.isEmpty)
                  const Text('No followers yet - invite family to join.'),
                for (final m in _members)
                  Card(
                    child: ListTile(
                      title: Text(m.displayName),
                      subtitle: Text(m.relationshipLabel ?? m.email ?? m.role),
                      trailing: Chip(label: Text(m.role)),
                    ),
                  ),
                if (_invites.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Pending invites', style: context.textStyles.labelLarge),
                  for (final inv in _invites)
                    ListTile(
                      title: Text(inv.email),
                      subtitle: Text(inv.status),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          await context
                              .read<AccountRepository>()
                              .revokeInvitation(widget.babyId, inv.id);
                          await _load();
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
