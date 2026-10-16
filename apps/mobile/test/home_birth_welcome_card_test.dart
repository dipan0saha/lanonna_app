import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/models/home_summary.dart';
import 'package:lanonna/features/home/presentation/widgets/home_birth_welcome_card.dart';

void main() {
  testWidgets('home birth welcome shows view announcement and share actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HomeBirthWelcomeCard(
            babyId: 'baby-1',
            welcome: const BirthWelcomeSummary(
              babyName: 'Parker',
              daysSinceBirth: 2,
              birthDate: '2026-10-02',
              weightText: '7 lb 4 oz',
              everyoneNotified: true,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('View Announcement'), findsOneWidget);
    expect(find.textContaining('Share to Instagram'), findsOneWidget);
    expect(find.textContaining('Born'), findsOneWidget);
    expect(find.bySemanticsIdentifier('home_share_announcement'), findsOneWidget);
  });
}
