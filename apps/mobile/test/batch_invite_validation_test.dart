import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/invitations/presentation/batch_invite_screen.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('batch invite blocks send when another row has invalid email', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OnboardingRepository>(
            create: (_) =>
                OnboardingRepository(ApiClient(idTokenProvider: () async => null)),
          ),
          Provider<HomeRepository>(
            create: (_) => HomeRepository(_OwnerBabyApi()),
          ),
          Provider<SelectedBabyStore>.value(value: store),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BatchInviteScreen(mode: BatchInviteMode.fromHome),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(BatchInviteScreen)),
    )!;

    await tester.enterText(
      find.byType(TextField).at(1),
      'qa-valid@example.com',
    );
    await tester.tap(find.text('Add another person'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(2), 'QA Typo Row');
    await tester.enterText(fields.at(3), 'qa-typo-no-at-sign');

    await tester.tap(find.text('Send Invites'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.batchInviteInvalidEmails), findsOneWidget);
    expect(find.text(l10n.validationEmailInvalid), findsOneWidget);
    expect(find.byType(BatchInviteScreen), findsOneWidget);
  });
}

class _OwnerBabyApi extends ApiClient {
  _OwnerBabyApi() : super(idTokenProvider: () async => 'token');

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool notifyMembershipEnded = true,
  }) async {
    if (path.startsWith('/v1/babies') && !path.contains('home-summary')) {
      return {
        'items': [
          {
            'id': 'baby-1',
            'name': 'Mira',
            'role': 'owner',
            'lifecycle_status': 'expecting',
          },
        ],
        'offset': 0,
        'limit': 100,
        'has_more': false,
      };
    }
    throw UnimplementedError(path);
  }
}
