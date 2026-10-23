import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/app_system_announcement_banner.dart';

void main() {
  testWidgets('AppSystemAnnouncementBanner shows title and body', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppSystemAnnouncementBanner(
            title: 'Scheduled maintenance',
            body: 'Saturday 2–4 AM',
            actions: const [TextButton(onPressed: null, child: Text('Dismiss'))],
          ),
        ),
      ),
    );

    expect(find.text('Scheduled maintenance'), findsOneWidget);
    expect(find.text('Saturday 2–4 AM'), findsOneWidget);
  });
}
