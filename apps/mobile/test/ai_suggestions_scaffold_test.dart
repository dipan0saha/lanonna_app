import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/ai_suggestions_scaffold.dart';

void main() {
  testWidgets('AI suggestions scaffold shows card row and + Add', (tester) async {
    var addTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AiSuggestionsScaffold(
          tabs: const [AiSuggestionTab(key: 'all', label: 'All')],
          selectedTab: 'all',
          onTabChanged: (_) {},
          loading: false,
          onRefresh: () async {},
          emptyMessage: 'Nothing here',
          items: [
            AiSuggestionListItem(
              title: 'Pediatric visit',
              description: 'Schedule first checkup',
              semanticsIdentifier: 'calendar_suggestion_add_test',
              onAdd: () => addTapped = true,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Pediatric visit'), findsOneWidget);
    expect(find.text('Schedule first checkup'), findsOneWidget);
    expect(find.text('+ Add'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);

    await tester.tap(find.text('+ Add'));
    await tester.pump();
    expect(addTapped, isTrue);

    final semantics = tester.getSemantics(find.text('+ Add'));
    expect(
      semantics.identifier,
      'calendar_suggestion_add_test',
    );
  });
}
