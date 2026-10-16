import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../../data/models/home_summary.dart';
import 'home_activity_feed.dart';
import 'home_owner_sections.dart';
import 'home_system_announcements_section.dart';
import 'home_teasers_section.dart';

/// PRD §6.2 sections #4–#14 (after hero/checklist blocks in composers).
class HomePrdSections extends StatelessWidget {
  const HomePrdSections({
    super.key,
    required this.summary,
    required this.babyId,
    required this.isOwner,
    required this.onRefresh,
    this.onTeaserSignedUrlError,
  });

  final HomeSummary summary;
  final String babyId;
  final bool isOwner;
  final VoidCallback onRefresh;
  final VoidCallback? onTeaserSignedUrlError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final teasers = summary.teasers;
    final showActivity = summary.isBorn || summary.recentActivity.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSystemAnnouncementsSection(
          items: summary.systemAnnouncements,
          onDismissed: onRefresh,
        ),
        if (showActivity)
          HomeActivityFeed(
            items: summary.recentActivity,
            babyId: babyId,
            showEmptyPlaceholder:
                summary.isBorn && summary.recentActivity.isEmpty,
            emptyMessage: l10n.homeBornActivityEmpty,
          ),
        if (teasers != null)
          HomeTeasersSection(
            teasers: teasers,
            onSignedUrlError: onTeaserSignedUrlError ?? onRefresh,
            includeUpcomingEvents:
                summary.nextUpEvent == null || summary.nextUpEvent!.id.isEmpty,
          ),
        if (isOwner) ...[
          HomeNewFollowersSection(
            followers: summary.newFollowers,
            babyId: babyId,
          ),
          HomeInviteStatusSection(
            invites: summary.inviteStatus,
            babyId: babyId,
            onChanged: onRefresh,
          ),
        ],
      ],
    );
  }
}
