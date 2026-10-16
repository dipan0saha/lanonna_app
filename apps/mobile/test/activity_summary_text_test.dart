import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/activity/activity_summary_text.dart';

void main() {
  testWidgets('ActivitySummaryText bolds actor prefix case-insensitively', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: ActivitySummaryText(
            summary: 'Added "stroller" to the registry',
            actorDisplayName: 'Grandma Sue',
          ),
        ),
      ),
    );

    final rich = tester.widget<RichText>(find.byType(RichText));
    final first = _firstTextSpan(rich.text);
    expect(first.text, 'Grandma Sue ');
    expect(first.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('ActivitySummaryText bolds actor embedded at summary start', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: ActivitySummaryText(
            summary: 'grandma sue commented on "Bump"',
            actorDisplayName: 'Grandma Sue',
          ),
        ),
      ),
    );

    final rich = tester.widget<RichText>(find.byType(RichText));
    final first = _firstTextSpan(rich.text);
    expect(first.style?.fontWeight, FontWeight.w700);
    expect(first.text, 'grandma sue');
  });
}

TextSpan _firstTextSpan(InlineSpan root) {
  TextSpan? found;
  root.visitChildren((span) {
    if (span is TextSpan && span.text != null) {
      found = span;
      return false;
    }
    return true;
  });
  return found!;
}
