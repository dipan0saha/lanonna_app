import 'package:flutter/material.dart';
import 'package:lanonna/core/domain/baby_display_label.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/baby_summary.dart';
import '../../../core/time/app_date_time.dart';
import '../data/models/home_summary.dart';
import '../domain/app_routes.dart';
import '../domain/home_composition.dart';
import 'widgets/home_next_up_section.dart';
import 'widgets/home_birth_welcome_card.dart';
import 'widgets/home_family_insight_gender_card.dart';
import 'widgets/home_follower_quick_actions.dart';
import 'widgets/home_insight_card.dart';
import 'widgets/home_prd_sections.dart';
import 'widgets/home_scroll_section.dart';
import 'widgets/owner_expecting_hero_card.dart';
import '../../../l10n/app_localizations.dart';

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
    this.hideVoteInFun = false,
  });

  final BabySummary baby;
  final HomeSummary? summary;
  final int? daysToDueDate;
  final VoidCallback onRefresh;
  final VoidCallback? onTeaserSignedUrlError;
  final VoidCallback onVoteInFun;
  final VoidCallback onViewGallery;
  final bool hideVoteInFun;

  bool get _isExpecting => !baby.isBorn;

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
    final l10n = AppLocalizations.of(context)!;
    final babyName = babyNameLabel(l10n, baby.name);
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
                AppLocalizations.of(context)!.homeYoullBeNotifiedTheMoment(babyName),
          ),
          HomeScrollSection(
            title: l10n.labelQuickActions,
            body: HomeFollowerQuickActions(
              onVoteInFun: hideVoteInFun ? null : onVoteInFun,
              onViewGallery: onViewGallery,
            ),
          ),
          if (s != null && HomeComposition.showNextUpCard(s))
            HomeNextUpSection(event: s.nextUpEvent!),
          if (s != null && s.showRichInsight)
            HomeFamilyInsightGenderCard(
              summary: s,
              onViewAll: () => context.go(AppRoutes.gamification),
            )
          else
            HomeScrollSection(
              title: l10n.messageInsight,
              body: HomeInsightCard(
                message:
                    l10n.emptyVotesYetCheckBack,
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
            showShareToInstagram: false,
            showViewAnnouncement:
                s.birthWelcome!.announcementId != null,
          ),
        HomeScrollSection(
          title: l10n.labelQuickActions,
          body: HomeFollowerQuickActions(
            onVoteInFun: hideVoteInFun ? null : onVoteInFun,
            onViewGallery: onViewGallery,
            useBornOutlineActions: true,
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
