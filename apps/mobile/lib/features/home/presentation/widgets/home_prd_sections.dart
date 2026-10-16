import 'package:flutter/material.dart';

import '../../data/models/home_summary.dart';
import 'home_activity_feed.dart';
import 'home_owner_sections.dart';
import 'home_system_announcements_section.dart';
import 'home_teasers_section.dart';

const _kBornHomeActivityEmptyMessage =
    'Nothing yet. Once family starts commenting and squishing photos, '
    "you'll see it here.";

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
    final teasers = summary.teasers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSystemAnnouncementsSection(
          items: summary.systemAnnouncements,
          onDismissed: onRefresh,
        ),
        if (summary.lifecycleStatus == 'born' ||
            summary.recentActivity.isNotEmpty)
          HomeActivityFeed(
            items: summary.recentActivity,
            babyId: babyId,
            showEmptyPlaceholder: summary.lifecycleStatus == 'born' &&
                summary.recentActivity.isEmpty,
            emptyMessage: _kBornHomeActivityEmptyMessage,
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
