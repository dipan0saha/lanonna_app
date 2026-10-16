import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/activity/activity_summary_text.dart';

void main() {
  testWidgets('ActivitySummaryText bolds the structured actor the copy names', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: ActivitySummaryText(
            summary: 'Grandma Sue commented on "Bump"',
            actorDisplayName: 'Grandma Sue',
          ),
        ),
      ),
    );

    final rich = tester.widget<RichText>(find.byType(RichText).last);
    final spans = <TextSpan>[];
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text != null) spans.add(span);
      return true;
    });
    expect(spans.first.text, 'Grandma Sue');
    expect(spans.first.style?.fontWeight, FontWeight.w700);
    expect(spans.map((s) => s.text).join(), 'Grandma Sue commented on "Bump"');
  });

  testWidgets('ActivitySummaryText never prefixes an actor the copy omits', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: ActivitySummaryText(
            summary: 'New event: Shower',
            actorDisplayName: 'Grandma Sue',
          ),
        ),
      ),
    );

    expect(find.text('New event: Shower'), findsOneWidget);
    expect(find.textContaining('Grandma Sue'), findsNothing);
  });

  testWidgets('ActivitySummaryText renders summary alone without actor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: ActivitySummaryText(summary: 'Family voted on gender'),
        ),
      ),
    );

    expect(find.text('Family voted on gender'), findsOneWidget);
    final text = tester.widget<Text>(find.text('Family voted on gender'));
    expect(text.textSpan, isNull);
  });
}
