import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/version/app_version_gate.dart';
import 'package:lanonna/core/version/app_version_service.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _VersionApi extends ApiClient {
  _VersionApi() : super(idTokenProvider: () async => null);

  final response = Completer<Map<String, dynamic>>();
  var requests = 0;

  @override
  Future<Map<String, dynamic>> getJsonPublic(String path, {Duration? timeout}) {
    requests++;
    return response.future;
  }
}

Widget _app(AppVersionService service) {
  return ChangeNotifierProvider<AppVersionService>.value(
    value: service,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: const AppVersionGate(child: Scaffold(body: Text('Ready'))),
    ),
  );
}

void main() {
  testWidgets('shows child while the check is in flight, then blocks', (
    tester,
  ) async {
    final api = _VersionApi();
    final service = AppVersionService(
      api,
      installedVersion: () async => '1.0.0',
    );
    unawaited(service.start());

    await tester.pumpWidget(_app(service));
    expect(find.text('Ready'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    api.response.complete({
      'minimum_version': '99.0.0',
      'store_url': 'https://example.com/store',
    });
    await tester.pumpAndSettle();

    expect(find.text('Ready'), findsNothing);
    expect(find.byType(AppVersionBlockScreen), findsOneWidget);
    // Rebuilding on the block must not start another check.
    expect(api.requests, 1);
  });

  testWidgets('current build keeps the child', (tester) async {
    final api = _VersionApi();
    final service = AppVersionService(
      api,
      installedVersion: () async => '1.0.0',
    );
    unawaited(service.start());
    await tester.pumpWidget(_app(service));

    api.response.complete({
      'minimum_version': '1.0.0',
      'store_url': 'https://example.com/store',
    });
    await tester.pumpAndSettle();

    expect(find.text('Ready'), findsOneWidget);
    expect(api.requests, 1);
  });
}
