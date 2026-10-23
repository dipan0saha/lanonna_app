import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/app_refresh_indicator.dart';
import 'package:lanonna/l10n/app_localizations.dart';

void main() {
  Future<void> pumpIndicator(
    WidgetTester tester,
    Future<void> Function() onRefresh,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AppRefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              key: const Key('list'),
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 800, child: Text('content'))],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pull(WidgetTester tester) async {
    await tester.drag(find.byKey(const Key('list')), const Offset(0, 320));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('a refresh that throws is reported and content stays', (
    tester,
  ) async {
    await pumpIndicator(
      tester,
      () async => throw const SocketException('failed host lookup'),
    );
    await pull(tester);

    final l10n = AppLocalizations.of(tester.element(find.text('content')))!;
    expect(find.text(l10n.errorOffline), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('a successful refresh shows no message', (tester) async {
    var calls = 0;
    await pumpIndicator(tester, () async => calls++);
    await pull(tester);

    expect(calls, 1);
    expect(find.byType(SnackBar), findsNothing);
  });
}
