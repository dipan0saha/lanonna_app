import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/baby_summary.dart';
import '../data/models/home_summary.dart';
import '../domain/app_routes.dart';
import 'widgets/home_birth_welcome_card.dart';
import 'widgets/home_family_insight_gender_card.dart';
import 'widgets/home_follower_quick_actions.dart';
import 'widgets/home_insight_card.dart';
import 'widgets/home_prd_sections.dart';
import 'widgets/home_section_header.dart';
import 'widgets/owner_expecting_hero_card.dart';

class FollowerHomeComposer extends StatelessWidget {
  const FollowerHomeComposer({
    super.key,
    required this.baby,
    required this.summary,
    required this.daysToDueDate,
    required this.onRefresh,
    required this.onVoteInFun,
    required this.onViewGallery,
  });

  final BabySummary baby;
  final HomeSummary? summary;
  final int? daysToDueDate;
  final VoidCallback onRefresh;
  final VoidCallback onVoteInFun;
  final VoidCallback onViewGallery;

  bool get _isExpecting => baby.lifecycleStatus == 'expecting';

  String? _formattedDueDate() {
    final raw = baby.expectedBirthDate;
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
          const HomeSectionHeader(title: 'Quick Actions'),
          HomeFollowerQuickActions(
            onVoteInFun: onVoteInFun,
            onViewGallery: onViewGallery,
          ),
          if (s != null && s.showRichInsight)
            HomeFamilyInsightGenderCard(
              summary: s,
              onViewAll: () => context.go(AppRoutes.gamification),
            )
          else ...[
            const HomeSectionHeader(title: 'Family Insight'),
            const HomeInsightCard(
              message:
                  'No family votes yet. Check back once everyone starts playing along in Fun.',
            ),
            const SizedBox(height: 18),
          ],
          if (s != null)
            HomePrdSections(
              summary: s,
              babyId: baby.id,
              isOwner: false,
              onRefresh: onRefresh,
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s?.birthWelcome != null)
          HomeBirthWelcomeCard(
            welcome: s!.birthWelcome!,
            babyId: baby.id,
            onSignedUrlError: onRefresh,
          ),
        const HomeSectionHeader(title: 'Quick Actions'),
        HomeFollowerQuickActions(
          onVoteInFun: onVoteInFun,
          onViewGallery: onViewGallery,
        ),
        if (s != null)
          HomePrdSections(
            summary: s!,
            babyId: baby.id,
            isOwner: false,
            onRefresh: onRefresh,
          ),
      ],
    );
  }
}
