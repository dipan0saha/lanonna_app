import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/version/app_version_gate.dart';
import 'package:lanonna/core/version/app_version_service.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _BlockingVersionApi extends ApiClient {
  _BlockingVersionApi()
    : super(idTokenProvider: () async => null);

  @override
  Future<Map<String, dynamic>> getJsonPublic(
    String path, {
    Duration? timeout,
  }) async {
    return {
      'minimum_version': '99.0.0',
      'store_url': 'https://example.com/store',
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('required update replaces child with block screen', (
    tester,
  ) async {
    final service = AppVersionService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>(create: (_) => _BlockingVersionApi()),
          ChangeNotifierProvider<AppVersionService>.value(value: service),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: AppVersionGate(
            child: const Scaffold(body: Text('Home content')),
          ),
        ),
      ),
    );

    expect(find.text('Home content'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Home content'), findsNothing);
    expect(find.byType(AppVersionBlockScreen), findsOneWidget);
  });
}
