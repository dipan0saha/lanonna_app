import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/activity/activity_feed_card.dart';
import 'package:lanonna/features/home/data/models/home_summary.dart';

void main() {
  testWidgets('ActivityFeedCard shows icon, actor bold, and timestamp', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ActivityFeedCard(
            items: [
              HomeActivityItem(
                id: '1',
                eventType: 'photo_comment',
                summary: 'Grandma Sue commented on "Bump update"',
                createdAt: DateTime.now().toUtc().toIso8601String(),
                actorDisplayName: 'Grandma Sue',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    expect(find.textContaining('Grandma Sue'), findsOneWidget);
    expect(find.textContaining('commented on'), findsOneWidget);
  });

  testWidgets('ActivityFeedCard shows empty state when requested', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: ActivityFeedCard(items: [], showEmptyState: true),
        ),
      ),
    );

    expect(
      find.text('Nothing yet - activity will show up here.'),
      findsOneWidget,
    );
  });
}
