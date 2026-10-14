import 'package:flutter/material.dart';

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
    final teasers = summary.teasers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSystemAnnouncementsSection(
          items: summary.systemAnnouncements,
          onDismissed: onRefresh,
        ),
        if (teasers != null)
          HomeTeasersSection(
            teasers: teasers,
            onSignedUrlError: onTeaserSignedUrlError ?? onRefresh,
          ),
        if (summary.recentActivity.isNotEmpty)
          HomeActivityFeed(
            items: summary.recentActivity,
            babyId: babyId,
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
