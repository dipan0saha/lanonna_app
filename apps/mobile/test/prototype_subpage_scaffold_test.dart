import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/prototype_subpage_scaffold.dart';

void main() {
  testWidgets('subpage scaffold shows title and no home top bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
theme: AppTheme.light,
        home: PrototypeSubpageScaffold(
          title: 'Settings',
          body: Center(child: Text('Body')),
        ),
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);

    final search = tester.widgetList<Semantics>(find.byType(Semantics));
    expect(
      search.any((s) => s.properties.identifier == 'shell_search'),
      isFalse,
    );
    expect(
      search.any((s) => s.properties.identifier == 'shell_baby_title'),
      isFalse,
    );
  });
}
