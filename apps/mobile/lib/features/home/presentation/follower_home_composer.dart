import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../onboarding/data/models/baby_summary.dart';
import '../data/models/home_summary.dart';
import 'widgets/home_activity_feed.dart';
import 'widgets/home_family_insight_gender_card.dart';
import 'widgets/home_follower_quick_actions.dart';
import 'widgets/home_insight_card.dart';
import 'widgets/home_next_up_card.dart';
import 'widgets/home_section_label.dart';
import 'widgets/owner_expecting_hero_card.dart';
import 'widgets/owner_welcome_banner.dart';

class FollowerHomeComposer extends StatelessWidget {
  const FollowerHomeComposer({
    super.key,
    required this.baby,
    required this.summary,
    required this.daysToDueDate,
    required this.onVoteInFun,
    required this.onViewGallery,
  });

  final BabySummary baby;
  final HomeSummary? summary;
  final int? daysToDueDate;
  final VoidCallback onVoteInFun;
  final VoidCallback onViewGallery;

  bool get _isExpecting => baby.lifecycleStatus == 'expecting';

  String? _formattedDueDate() {
    final raw = baby.expectedBirthDate;
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    final babyName = baby.name;
    final s = summary;

    if (_isExpecting) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OwnerExpectingHeroCard(
            babyName: babyName,
            daysToDueDate: daysToDueDate ?? s?.daysToDue,
            showAnnounceCta: false,
            dueDateLabel: _formattedDueDate(),
            followerFootnote:
                "You'll be notified the moment $babyName arrives.",
          ),
          const HomeSectionLabel('Quick Actions'),
          HomeFollowerQuickActions(
            onVoteInFun: onVoteInFun,
            onViewGallery: onViewGallery,
          ),
          if (s?.nextUpEvent != null && s!.nextUpEvent!.title.isNotEmpty)
            HomeNextUpCard(event: s.nextUpEvent!),
          if (s != null && s.showRichInsight)
            HomeFamilyInsightGenderCard(
              summary: s,
              onViewAll: () => context.go('/gamification'),
            )
          else ...[
            const HomeSectionLabel('Family Insight'),
            const HomeInsightCard(
              message:
                  'No family votes yet. Check back once everyone starts playing along in Fun.',
            ),
            const SizedBox(height: 18),
          ],
          if (s != null && s.recentActivity.isNotEmpty)
            HomeActivityFeed(items: s.recentActivity),
        ],
      );
    }

    final activityLines =
        s?.recentActivity.map((e) => e.summary).toList() ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OwnerWelcomeBanner(babyName: babyName),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: OutlinedButton(
            onPressed: () => context.push('/baby/${baby.id}/announcement'),
            child: const Text('View Announcement'),
          ),
        ),
        const SizedBox(height: 8),
        const HomeSectionLabel('Quick Actions'),
        HomeFollowerQuickActions(
          onVoteInFun: onVoteInFun,
          onViewGallery: onViewGallery,
        ),
        if (s != null && s.showRichInsight)
          HomeFamilyInsightGenderCard(
            summary: s,
            onViewAll: () => context.go('/gamification'),
          )
        else ...[
          const HomeSectionLabel('Family Insight'),
          HomeInsightCard(
            tinted: false,
            message: activityLines.isEmpty
                ? "Nothing yet. Once family starts commenting and squishing photos, you'll see it here."
                : 'Latest updates',
            activityLines: activityLines,
          ),
          const SizedBox(height: 18),
        ],
        if (s != null && s.recentActivity.isNotEmpty)
          HomeActivityFeed(items: s.recentActivity),
      ],
    );
  }
}
