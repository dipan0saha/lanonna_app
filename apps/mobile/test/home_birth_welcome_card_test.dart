import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/models/home_summary.dart';
import 'package:lanonna/features/home/presentation/widgets/home_birth_welcome_card.dart';

void main() {
  testWidgets('home birth welcome shows view card and share actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HomeBirthWelcomeCard(
            babyId: 'baby-1',
            welcome: BirthWelcomeSummary(
              babyName: 'Parker',
              daysSinceBirth: 2,
            ),
          ),
        ),
      ),
    );

    expect(find.text('View card'), findsOneWidget);
    expect(find.text('Share to Instagram'), findsOneWidget);
    expect(find.bySemanticsIdentifier('home_share_announcement'), findsOneWidget);
  });
}
