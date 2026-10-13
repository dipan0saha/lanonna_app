import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../account/data/account_repository.dart';
import '../../data/models/home_summary.dart';
import 'home_scroll_section.dart';

class HomeNewFollowersSection extends StatelessWidget {
  const HomeNewFollowersSection({
    super.key,
    required this.followers,
    required this.babyId,
  });

  final List<HomeNewFollower> followers;
  final String babyId;

  @override
  Widget build(BuildContext context) {
    if (followers.isEmpty) return const SizedBox.shrink();
    return HomeScrollSection.bordered(
      title: 'New Followers',
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final f in followers)
            ListTile(
              title: Text(f.displayName),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
            ),
          TextButton(
            onPressed: () => context.push('/baby/$babyId/followers'),
            child: const Text('Manage followers'),
          ),
        ],
      ),
    );
  }
}

class HomeInviteStatusSection extends StatelessWidget {
  const HomeInviteStatusSection({
    super.key,
    required this.invites,
    required this.babyId,
    required this.onChanged,
  });

  final List<HomeInviteStatusRow> invites;
  final String babyId;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (invites.isEmpty) return const SizedBox.shrink();
    return HomeScrollSection.bordered(
      title: 'Invite Status',
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final inv in invites)
            ListTile(
              title: Text(inv.inviteeEmail),
              subtitle: Text(inv.status),
              trailing: AppIconButton(
                semanticsId: 'home_revoke_invite_${inv.id}',
                label: 'Revoke invitation',
                icon: const Icon(Icons.close),
                onPressed: () async {
                  await context.read<AccountRepository>().revokeInvitation(
                    babyId,
                    inv.id,
                  );
                  onChanged();
                },
              ),
            ),
        ],
      ),
    );
  }
}
