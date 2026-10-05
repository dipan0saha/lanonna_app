import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../account/data/account_repository.dart';
import '../../../registry/domain/registry_routes.dart';
import '../../data/models/home_summary.dart';
import 'home_section_header.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HomeSectionHeader(title: 'New Followers'),
        Card(
          margin: EdgeInsets.symmetric(horizontal: AppMetrics.horizontalPadding),
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
        ),
        const SizedBox(height: 12),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HomeSectionHeader(title: 'Invite Status'),
        Card(
          margin: EdgeInsets.symmetric(horizontal: AppMetrics.horizontalPadding),
          child: Column(
            children: [
              for (final inv in invites)
                ListTile(
                  title: Text(inv.inviteeEmail),
                  subtitle: Text(inv.status),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      await context
                          .read<AccountRepository>()
                          .revokeInvitation(babyId, inv.id);
                      onChanged();
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class HomeRegistryHighlightsList extends StatelessWidget {
  const HomeRegistryHighlightsList({super.key, required this.items});

  final List<HomeRegistryHighlight> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HomeSectionHeader(title: 'Registry Highlights'),
        Card(
          margin: EdgeInsets.symmetric(horizontal: AppMetrics.horizontalPadding),
          child: Column(
            children: items
                .map(
                  (item) => ListTile(
                    title: Text(item.name),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                    onTap: () => context.push(
                      RegistryRoutes.itemEdit(item.id),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class HomeRecentPurchasesSection extends StatelessWidget {
  const HomeRecentPurchasesSection({
    super.key,
    required this.purchases,
    required this.isOwner,
  });

  final List<HomeRecentPurchase> purchases;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    if (purchases.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HomeSectionHeader(title: 'Recent Registry Purchases'),
        Card(
          margin: EdgeInsets.symmetric(horizontal: AppMetrics.horizontalPadding),
          child: Column(
            children: purchases.map((p) {
              final subtitle = isOwner && p.purchaserDisplayName != null
                  ? '${p.purchaserDisplayName} is buying'
                  : 'Recently claimed';
              return ListTile(
                title: Text(p.itemName),
                subtitle: Text(subtitle),
                onTap: () => context.push(RegistryRoutes.itemEdit(p.itemId)),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
