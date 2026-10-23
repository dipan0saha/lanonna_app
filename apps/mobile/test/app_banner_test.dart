import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/app_banner.dart';
import 'package:lanonna/features/home/data/models/home_summary.dart';
import 'package:lanonna/features/home/presentation/widgets/home_system_announcements_section.dart';
import 'package:lanonna/l10n/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('AppBanner shows the title above the message', (tester) async {
    await tester.pumpWidget(
      _app(
        const AppBanner(
          title: 'Scheduled maintenance',
          message: 'Saturday 2–4 AM',
          actions: [TextButton(onPressed: null, child: Text('Dismiss'))],
        ),
      ),
    );
    final title = tester.getTopLeft(find.text('Scheduled maintenance'));
    final body = tester.getTopLeft(find.text('Saturday 2–4 AM'));
    expect(title.dy, lessThan(body.dy));
  });

  testWidgets('AppBanner without a title shows only the message', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const AppBanner(
          title: '  ',
          message: 'Could not load',
          actions: [TextButton(onPressed: null, child: Text('Retry'))],
        ),
      ),
    );
    expect(find.text('Could not load'), findsOneWidget);
    expect(find.byType(Text), findsNWidgets(2));
  });

  testWidgets('Home system announcements render the API title (#392)', (
    tester,
  ) async {
    final item = SystemAnnouncementItem.fromJson({
      'id': 'a1',
      'title': 'Scheduled maintenance',
      'body': 'Saturday 2–4 AM',
    });
    await tester.pumpWidget(
      _app(HomeSystemAnnouncementsSection(items: [item], onDismissed: () {})),
    );
    expect(find.text('Scheduled maintenance'), findsOneWidget);
    expect(find.text('Saturday 2–4 AM'), findsOneWidget);
    expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
  });
}
