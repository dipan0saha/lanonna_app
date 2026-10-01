import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Followers'),
        actions: [
          TextButton(
            onPressed: () => context.push('/invite-family'),
            child: const Text('Invite'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_members.isEmpty && _invites.isEmpty)
                  const Text('No followers yet — invite family to join.'),
                if (_members.isNotEmpty) ...[
                  const Text('Members', style: TextStyle(fontWeight: FontWeight.bold)),
                  for (final m in _members)
                    ListTile(
                      title: Text(m.displayName),
                      subtitle: Text(m.relationshipLabel ?? m.email ?? m.role),
                      trailing: Chip(label: Text(m.role)),
                    ),
                ],
                if (_invites.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Pending invites', style: TextStyle(fontWeight: FontWeight.bold)),
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
              ],
            ),
    );
  }
}
