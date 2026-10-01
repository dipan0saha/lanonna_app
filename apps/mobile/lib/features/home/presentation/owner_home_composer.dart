import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../onboarding/data/models/baby_summary.dart';
import '../data/models/home_summary.dart';
import '../domain/app_routes.dart';
import 'widgets/home_activity_feed.dart';
import 'widgets/home_family_insight_gender_card.dart';
import 'widgets/home_insight_card.dart';
import 'widgets/home_next_up_card.dart';
import 'widgets/home_section_label.dart';
import 'widgets/owner_expecting_hero_card.dart';
import 'widgets/owner_getting_started_card.dart';
import 'widgets/owner_quick_actions_row.dart';
import 'widgets/owner_welcome_banner.dart';

class OwnerHomeComposer extends StatelessWidget {
  const OwnerHomeComposer({
    super.key,
    required this.baby,
    required this.summary,
    required this.daysToDueDate,
    this.onAnnounceTap,
    this.onAddPhoto,
    this.onAddEvent,
    this.onRegistry,
  });

  final BabySummary baby;
  final HomeSummary? summary;
  final int? daysToDueDate;
  final VoidCallback? onAnnounceTap;
  final VoidCallback? onAddPhoto;
  final VoidCallback? onAddEvent;
  final VoidCallback? onRegistry;

  bool get _isExpecting => baby.lifecycleStatus == 'expecting';

  bool get _isPopulated {
    final gs = summary?.gettingStarted;
    if (gs == null) return false;
    return gs.completedCount > 0;
  }

  @override
  Widget build(BuildContext context) {
    final babyName = baby.name;

    if (_isExpecting) {
      final s = summary;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OwnerExpectingHeroCard(
            babyName: babyName,
            daysToDueDate: daysToDueDate ?? s?.daysToDue,
            onAnnounceTap: onAnnounceTap,
          ),
          if (_isPopulated && onAddPhoto != null && onAddEvent != null && onRegistry != null) ...[
            const SizedBox(height: 8),
            OwnerQuickActionsRow(
              onAddPhoto: onAddPhoto!,
              onAddEvent: onAddEvent!,
              onRegistry: onRegistry!,
            ),
            const SizedBox(height: 18),
          ],
          if (s?.nextUpEvent != null && s!.nextUpEvent!.title.isNotEmpty)
            HomeNextUpCard(event: s.nextUpEvent!),
          if (s != null && s.showRichInsight)
            HomeFamilyInsightGenderCard(
              summary: s,
              onViewAll: () => context.go('/gamification'),
            )
          else ...[
            const HomeSectionLabel('Family Insight'),
            HomeInsightCard(
              message:
                  'No votes yet. Invite family so they can guess names, gender, and the big day.',
              actionLabel: 'Invite',
              onAction: () => context.push(AppRoutes.inviteFamily),
            ),
            const SizedBox(height: 18),
          ],
          if (s != null && s.gettingStarted != null)
            OwnerGettingStartedCard(
              summary: s.gettingStarted!,
              babyId: baby.id,
            ),
          if (s != null && s.recentActivity.isNotEmpty)
            HomeActivityFeed(items: s.recentActivity),
        ],
      );
    }

    final activityLines =
        summary?.recentActivity.map((e) => e.summary).toList() ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OwnerWelcomeBanner(babyName: babyName),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Instagram share coming soon')),
            );
          },
          icon: const Icon(Icons.camera_alt_outlined, size: 18),
          label: const Text('Share to Instagram'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.push('/baby/${baby.id}/announcement'),
          child: const Text('View Announcement'),
        ),
        const HomeSectionLabel('Recent Activity'),
        HomeInsightCard(
          tinted: false,
          message: activityLines.isEmpty
              ? "Nothing yet. Once family starts commenting and squishing photos, you'll see it here."
              : 'Latest updates',
          activityLines: activityLines,
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}
