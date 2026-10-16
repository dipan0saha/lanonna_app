import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/account/data/notifications_repository.dart';
import 'package:lanonna/features/account/presentation/widgets/inbox_notification_row.dart';

void main() {
  testWidgets('inbox row uses two lines with relative time', (tester) async {
    final created = DateTime.now().subtract(const Duration(minutes: 2));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: InboxNotificationRow(
            notification: InboxNotification(
              id: 'n1',
              title: 'New comment',
              body: 'Sarah commented on "First Ultrasound"',
              createdAt: created,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Sarah'), findsOneWidget);
    expect(find.textContaining('commented on'), findsOneWidget);
    expect(find.textContaining('minutes ago'), findsOneWidget);
  });
}
