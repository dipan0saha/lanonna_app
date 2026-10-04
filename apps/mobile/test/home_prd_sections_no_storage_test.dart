import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/models/home_summary.dart';
import 'package:lanonna/features/home/presentation/widgets/home_prd_sections.dart';

void main() {
  testWidgets('owner HomePrdSections does not show storage meter', (tester) async {
    const summary = HomeSummary(
      lifecycleStatus: 'expecting',
      nameSuggestionCount: 0,
      voteCount: 0,
      recentActivity: [],
      inviteStatus: [
        HomeInviteStatusRow(
          id: 'inv-1',
          inviteeEmail: 'family@example.com',
          status: 'pending',
          createdAt: '2026-10-01T12:00:00Z',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HomePrdSections(
            summary: summary,
            babyId: 'baby-1',
            isOwner: true,
            onRefresh: () {},
          ),
        ),
      ),
    );

    expect(find.text('Storage'), findsNothing);
  });
}
