import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/models/home_summary.dart';
import 'package:lanonna/features/home/presentation/follower_home_composer.dart';
import 'package:lanonna/core/domain/baby_summary.dart';

void main() {
  testWidgets('follower expecting shows notification footnote not announce', (tester) async {
    const baby = BabySummary(
      id: 'b1',
      name: 'Parker',
      lifecycleStatus: 'expecting',
      expectedBirthDate: '2026-10-08',
      role: 'follower',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FollowerHomeComposer(
            baby: baby,
            summary: null,
            daysToDueDate: 14,
            onRefresh: () {},
            onVoteInFun: () {},
            onViewGallery: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining("You'll be notified"), findsOneWidget);
    expect(find.text('Announce Arrival'), findsNothing);
    expect(find.text('Invite'), findsNothing);
    expect(find.text('Vote in Fun'), findsOneWidget);
  });

  testWidgets('follower expecting with summary shows upcoming events', (tester) async {
    const baby = BabySummary(
      id: 'b1',
      name: 'Parker',
      lifecycleStatus: 'expecting',
      expectedBirthDate: '2026-10-08',
      role: 'follower',
    );
    const summary = HomeSummary(
      lifecycleStatus: 'expecting',
      nameSuggestionCount: 0,
      voteCount: 5,
      recentActivity: const [],
      genderTotals: const GenderTotals(male: 3, female: 2),
      teasers: HomeTeasers(
        recentPhotos: const [],
        favoritePhotos: const [],
        registryOpenCount: 0,
        registryHighlights: const [],
        recentPurchases: const [],
        upcomingEvents: const [
          NextUpEvent(
            id: 'e1',
            title: 'Gender Reveal Party',
            startsAt: '2026-10-02T18:00:00Z',
          ),
        ],
        rsvpReminders: const [],
        notificationPreview: const [],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: FollowerHomeComposer(
              baby: baby,
              summary: summary,
              daysToDueDate: 14,
              onRefresh: () {},
              onVoteInFun: () {},
              onViewGallery: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Gender Reveal Party'), findsOneWidget);
    expect(find.text('UPCOMING EVENTS'), findsOneWidget);
  });
}
