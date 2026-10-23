import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_exception.dart';
import 'package:lanonna/core/presentation/detail_screen_load.dart';
import 'package:lanonna/l10n/app_localizations.dart';

void main() {
  testWidgets('reportDetailLoadFailure blocks when no content', (tester) async {
    String? captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                reportDetailLoadFailure(
                  context,
                  ApiException('err', statusCode: 500),
                  hasContent: false,
                  onBlockingError: (message) => captured = message,
                );
              },
              child: const Text('fail'),
            );
          },
        ),
        ),
      ),
    );
    await tester.tap(find.text('fail'));
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured, isNotEmpty);
  });

  testWidgets('reportDetailLoadFailure snackbars when content exists', (
    tester,
  ) async {
    var blocked = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                reportDetailLoadFailure(
                  context,
                  ApiException('err', statusCode: 500),
                  hasContent: true,
                  onBlockingError: (_) => blocked = true,
                );
              },
              child: const Text('fail'),
            );
          },
        ),
        ),
      ),
    );
    await tester.tap(find.text('fail'));
    await tester.pump();
    expect(blocked, isFalse);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  for (final withHandler in [true, false]) {
    testWidgets('404 is not-found only when the screen handles it '
        '(handler: $withHandler)', (tester) async {
      var notFound = false;
      String? blocking;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => reportDetailLoadFailure(
                context,
                ApiException('gone', statusCode: 404),
                hasContent: false,
                onNotFound: withHandler ? () => notFound = true : null,
                onBlockingError: (m) => blocking = m,
              ),
              child: const Text('fail'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('fail'));
      await tester.pump();
      expect(notFound, withHandler);
      expect(blocking == null, withHandler);
    });
  }
}
