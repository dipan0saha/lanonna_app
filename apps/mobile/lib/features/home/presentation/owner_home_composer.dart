import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/baby_summary.dart';
import '../data/models/home_summary.dart';
import '../domain/app_routes.dart';
import 'widgets/home_birth_welcome_card.dart';
import 'widgets/home_family_insight_gender_card.dart';
import 'widgets/home_insight_card.dart';
import 'widgets/home_prd_sections.dart';
import 'widgets/home_scroll_section.dart';
import 'widgets/owner_expecting_hero_card.dart';
import 'widgets/owner_getting_started_card.dart';
import 'widgets/owner_quick_actions_row.dart';

class OwnerHomeComposer extends StatelessWidget {
  const OwnerHomeComposer({
    super.key,
    required this.baby,
    required this.summary,
    required this.daysToDueDate,
    required this.onRefresh,
    this.onAnnounceTap,
    this.onAddPhoto,
    this.onAddEvent,
    this.onRegistry,
  });

  final BabySummary baby;
  final HomeSummary? summary;
  final int? daysToDueDate;
  final VoidCallback onRefresh;
  final VoidCallback? onAnnounceTap;
  final VoidCallback? onAddPhoto;
  final VoidCallback? onAddEvent;
  final VoidCallback? onRegistry;

  bool get _isExpecting => baby.lifecycleStatus == 'expecting';

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
            onAnnounceTap: onAnnounceTap,
          ),
          if (onAddPhoto != null && onAddEvent != null && onRegistry != null) ...[
            const SizedBox(height: 8),
            OwnerQuickActionsRow(
              onAddPhoto: onAddPhoto!,
              onAddEvent: onAddEvent!,
              onRegistry: onRegistry!,
            ),
            const SizedBox(height: 18),
          ],
          if (s != null && s.showRichInsight)
            HomeFamilyInsightGenderCard(
              summary: s,
              onViewAll: () => context.go(AppRoutes.gamification),
            )
          else
            HomeScrollSection(
              title: 'Family Insight',
              body: HomeInsightCard(
                message:
                    'No votes yet. Invite family so they can guess names, gender, and the big day.',
                actionLabel: 'Invite',
                onAction: () => context.push(AppRoutes.inviteFamily),
              ),
            ),
          if (s != null && s.gettingStarted != null)
            OwnerGettingStartedCard(
              summary: s.gettingStarted!,
              babyId: baby.id,
            ),
          if (s != null)
            HomePrdSections(
              summary: s,
              babyId: baby.id,
              isOwner: true,
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
        if (s != null)
          HomePrdSections(
            summary: s,
            babyId: baby.id,
            isOwner: true,
            onRefresh: onRefresh,
          ),
      ],
    );
  }
}
