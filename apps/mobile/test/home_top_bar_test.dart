import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/presentation/widgets/home_top_bar.dart';
import 'package:lanonna/l10n/app_localizations.dart';

void main() {
  testWidgets('shell leading actions expose add and invite semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HomeTopBar(
            onAddBabyTap: () {},
            onInviteFamilyTap: () {},
          ),
        ),
      ),
    );

    final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
    expect(
      semantics.any((s) => s.properties.identifier == 'shell_add_baby'),
      isTrue,
    );
    expect(
      semantics.any((s) => s.properties.identifier == 'shell_invite_family'),
      isTrue,
    );
    expect(
      semantics.any((s) => s.properties.identifier == 'shell_search'),
      isFalse,
    );
    expect(find.byIcon(Icons.group_add_outlined), findsOneWidget);
  });
}
