import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/domain/person_display_label.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../account/data/account_repository.dart';
import '../../data/models/home_summary.dart';
import 'home_scroll_section.dart';
import '../../../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    if (followers.isEmpty) return const SizedBox.shrink();
    return HomeScrollSection.bordered(
      title: l10n.labelNewFollowers,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final f in followers)
            ListTile(
              title: Text(personDisplayName(l10n, f.displayName)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
            ),
          TextButton(
            onPressed: () => context.push('/baby/$babyId/followers'),
            child: Text(l10n.actionManageFollowers),
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
    final l10n = AppLocalizations.of(context)!;
    if (invites.isEmpty) return const SizedBox.shrink();
    return HomeScrollSection.bordered(
      title: l10n.actionInviteStatus,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final inv in invites)
            ListTile(
              title: Text(inv.inviteeEmail),
              subtitle: Text(inv.status.label(l10n)),
              trailing: AppIconButton(
                semanticsId: 'home_revoke_invite_${inv.id}',
                label: l10n.actionRevokeInvitation,
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
