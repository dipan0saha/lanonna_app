import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/baby_summary.dart';
import '../../../core/time/app_date_time.dart';
import '../data/models/home_summary.dart';
import '../domain/app_routes.dart';
import 'widgets/home_birth_welcome_card.dart';
import 'widgets/home_family_insight_gender_card.dart';
import 'widgets/home_follower_quick_actions.dart';
import 'widgets/home_insight_card.dart';
import 'widgets/home_prd_sections.dart';
import 'widgets/home_scroll_section.dart';
import 'widgets/owner_expecting_hero_card.dart';

class FollowerHomeComposer extends StatelessWidget {
  const FollowerHomeComposer({
    super.key,
    required this.baby,
    required this.summary,
    required this.daysToDueDate,
    required this.onRefresh,
    this.onTeaserSignedUrlError,
    required this.onVoteInFun,
    required this.onViewGallery,
  });

  final BabySummary baby;
  final HomeSummary? summary;
  final int? daysToDueDate;
  final VoidCallback onRefresh;
  final VoidCallback? onTeaserSignedUrlError;
  final VoidCallback onVoteInFun;
  final VoidCallback onViewGallery;

  bool get _isExpecting => baby.lifecycleStatus == 'expecting';

  String? _formattedDueDate(BuildContext context) {
    final raw = baby.expectedBirthDate;
    if (raw == null || raw.isEmpty) return null;
    final formatted = formatApiCalendarDate(
      raw,
      localeNameForFormatting(context),
    );
    return formatted.isEmpty ? null : formatted;
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
            dueDateLabel: _formattedDueDate(context),
            followerFootnote:
                "You'll be notified the moment $babyName arrives.",
          ),
          HomeScrollSection(
            title: 'Quick Actions',
            body: HomeFollowerQuickActions(
              onVoteInFun: onVoteInFun,
              onViewGallery: onViewGallery,
            ),
          ),
          if (s != null && s.showRichInsight)
            HomeFamilyInsightGenderCard(
              summary: s,
              onViewAll: () => context.go(AppRoutes.gamification),
            )
          else
            const HomeScrollSection(
              title: 'Family Insight',
              body: HomeInsightCard(
                message:
                    'No family votes yet. Check back once everyone starts playing along in Fun.',
              ),
            ),
          if (s != null)
            HomePrdSections(
              summary: s,
              babyId: baby.id,
              isOwner: false,
              onRefresh: onRefresh,
              onTeaserSignedUrlError: onTeaserSignedUrlError,
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
        HomeScrollSection(
          title: 'Quick Actions',
          body: HomeFollowerQuickActions(
            onVoteInFun: onVoteInFun,
            onViewGallery: onViewGallery,
          ),
        ),
        if (s != null)
          HomePrdSections(
            summary: s,
            babyId: baby.id,
            isOwner: false,
            onRefresh: onRefresh,
            onTeaserSignedUrlError: onTeaserSignedUrlError,
          ),
      ],
    );
  }
}
