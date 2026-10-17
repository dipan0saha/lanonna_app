import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/activity_event_type.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/activity/activity_feed_card.dart';
import 'package:lanonna/core/widgets/activity/feed_sentence.dart';
import 'package:lanonna/features/home/data/models/home_summary.dart';
import 'package:lanonna/l10n/app_localizations.dart';

Future<void> _pump(WidgetTester tester, List<HomeActivityItem> items) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: Scaffold(body: ActivityFeedCard(items: items)),
    ),
  );
}

List<TextSpan> _boldSpans(WidgetTester tester) {
  final rich = tester.widget<RichText>(
    find.descendant(
      of: find.byType(FeedSentenceText),
      matching: find.byType(RichText),
    ),
  );
  final spans = <TextSpan>[];
  rich.text.visitChildren((span) {
    if (span is TextSpan &&
        span.text != null &&
        span.style?.fontWeight == FontWeight.w700) {
      spans.add(span);
    }
    return true;
  });
  return spans;
}

void main() {
  testWidgets('renders the ARB sentence with the actor in bold', (
    tester,
  ) async {
    await _pump(tester, [
      HomeActivityItem(
        id: '1',
        eventType: ActivityEventType.photoComment,
        params: const {'caption': 'Bump update'},
        summary: 'server copy is not shown',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        actorDisplayName: 'Grandma Sue',
        photoId: 'photo-1',
      ),
    ]);

    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    expect(
      find.text('Grandma Sue commented on "Bump update"', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('server copy'), findsNothing);
    expect(_boldSpans(tester).map((s) => s.text), ['Grandma Sue']);
    expect(
      find.bySemanticsLabel(
        RegExp(RegExp.escape('Grandma Sue commented on "Bump update"')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a member without a name gets the localized fallback', (
    tester,
  ) async {
    await _pump(tester, [
      const HomeActivityItem(
        id: '1',
        eventType: ActivityEventType.memberRemoved,
        summary: '',
        createdAt: '2026-10-01T12:00:00Z',
      ),
    ]);
    expect(
      find.text(
        'Family member removed a member from the family',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('unknown types and legacy rows fall back to the stored summary', (
    tester,
  ) async {
    await _pump(tester, [
      const HomeActivityItem(
        id: '1',
        eventType: null,
        summary: 'Sarah did something new',
        createdAt: '2026-10-01T12:00:00Z',
        actorDisplayName: 'Sarah',
      ),
      const HomeActivityItem(
        id: '2',
        eventType: ActivityEventType.registryItemAdded,
        summary: 'Sarah added "Stroller" to the registry',
        createdAt: '2026-10-01T12:00:00Z',
        actorDisplayName: 'Sarah',
      ),
    ]);
    expect(find.text('Sarah did something new', findRichText: true), findsOneWidget);
    expect(
      find.text('Sarah added "Stroller" to the registry', findRichText: true),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.notifications_none_outlined), findsOneWidget);
  });

  testWidgets('ActivityFeedCard shows empty state when requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
