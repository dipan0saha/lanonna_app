import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/account/presentation/widgets/account_profile_card.dart';

void main() {
  testWidgets('AccountProfileCard shows name, email, and actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Scaffold(
          body: AccountProfileCard(
            displayName: 'Sarah Chen',
            email: 'sarah@example.com',
            onEdit: () {},
            onLogOut: () {},
          ),
        ),
      ),
    );

    expect(find.text('Sarah Chen'), findsOneWidget);
    expect(find.text('sarah@example.com'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNWidgets(2));
  });
}
