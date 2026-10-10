import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/announcement/data/announcement_repository.dart';
import 'package:lanonna/features/announcement/presentation/widgets/announcement_keepsake_card.dart';

void main() {
  testWidgets('keepsake card formats birth date for display', (tester) async {
    final detail = AnnouncementDetail(
      id: 'a1',
      firstName: 'Probe',
      birthDate: '2026-10-10',
      squishCount: 0,
      commentCount: 0,
      comments: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: AnnouncementKeepsakeCard(detail: detail),
        ),
      ),
    );

    expect(find.textContaining('2026-10-10'), findsNothing);
    expect(find.textContaining('October'), findsOneWidget);
    expect(find.textContaining('10'), findsWidgets);
    expect(find.textContaining('2026'), findsOneWidget);
  });
}
