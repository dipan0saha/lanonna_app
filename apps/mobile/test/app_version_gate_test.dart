import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/version/app_version_gate.dart';
import 'package:lanonna/core/version/app_version_service.dart';
import 'package:provider/provider.dart';

class _SlowVersionApiClient extends ApiClient {
  _SlowVersionApiClient()
      : super(idTokenProvider: () async => null);

  @override
  Future<Map<String, dynamic>> getJsonPublic(
    String path, {
    Duration? timeout,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 30));
    return {
      'minimum_version': '99.0.0',
      'store_url': 'https://example.com/store',
    };
  }
}

void main() {
  testWidgets('shows child while version check is in flight', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>(create: (_) => _SlowVersionApiClient()),
          ChangeNotifierProvider(create: (_) => AppVersionService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: AppVersionGate(
            child: const Scaffold(body: Text('Ready')),
          ),
        ),
      ),
    );

    expect(find.text('Ready'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
