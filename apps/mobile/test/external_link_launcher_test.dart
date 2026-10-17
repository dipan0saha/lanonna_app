import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:lanonna/core/platform/external_link_launcher.dart';

void main() {
  testWidgets('failed launch shows a snackbar with Copy link', (tester) async {
    final uri = Uri.parse('https://example.com/export.json');
    await tester.pumpWidget(
      MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => openExternalLink(
                context,
                uri,
                failureMessage: "Couldn't open the download. Copy link?",
                launch: (_) async {
                  throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
                },
              ),
              child: const Text('Download export'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Download export'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(find.text("Couldn't open the download. Copy link?"), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a false launch result is the same fallback', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => openExternalLink(
                context,
                Uri.parse('https://example.com/store'),
                launch: (_) async => false,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(find.text("Couldn't open the link. Copy link?"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
