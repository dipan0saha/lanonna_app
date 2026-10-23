import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/invitations/data/batch_invite_result.dart';
import 'package:lanonna/features/invitations/presentation/batch_invite_screen.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/presentation/app_session.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// #422: a send never drops a row the user filled in.
void main() {
  late _RecordingOnboardingRepository repository;

  Future<AppLocalizations> pumpScreen(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = OnboardingStorage(prefs);
    repository = _RecordingOnboardingRepository();
    final coordinator = OnboardingCoordinator(
      storage: storage,
      repository: repository,
    );
    final router = GoRouter(
      initialLocation: '/invite',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(
              path: 'invite',
              builder: (_, _) =>
                  const BatchInviteScreen(mode: BatchInviteMode.fromHome),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OnboardingRepository>.value(value: repository),
          Provider<HomeRepository>(
            create: (_) => HomeRepository(_OwnerBabyApi()),
          ),
          ChangeNotifierProvider<SelectedBabyStore>(
            create: (_) => SelectedBabyStore(prefs),
          ),
          ChangeNotifierProvider<OnboardingCoordinator>.value(
            value: coordinator,
          ),
          ChangeNotifierProvider<AppSession>(
            create: (_) => AppSession(
              repository: repository,
              storage: storage,
              coordinator: coordinator,
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(BatchInviteScreen)),
    )!;
  }

  Future<void> addRow(WidgetTester tester) async {
    final button = find.text('+ Add another person');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester) async {
    final button = find.text('Send Invites');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  // Each row is a name field then an email field.
  Finder field(int index) => find.byType(TextField).at(index);

  testWidgets('an invalid email in one row blocks the whole send', (
    tester,
  ) async {
    final l10n = await pumpScreen(tester);
    await tester.enterText(field(1), 'qa-valid@example.com');
    await addRow(tester);
    await tester.enterText(field(2), 'QA Typo Row');
    await tester.enterText(field(3), 'qa-typo-no-at-sign');

    await send(tester);

    expect(repository.sent, isEmpty);
    expect(find.text(l10n.batchInviteInvalidEmails), findsOneWidget);
    expect(find.text(l10n.validationEmailInvalid), findsOneWidget);
    expect(find.byType(BatchInviteScreen), findsOneWidget);

    // Fixing the typo clears the field error as the user types.
    await tester.enterText(field(3), 'qa-typo@example.com');
    await tester.pumpAndSettle();
    expect(find.text(l10n.validationEmailInvalid), findsNothing);
  });

  testWidgets('a row with a name but no email asks for the email', (
    tester,
  ) async {
    final l10n = await pumpScreen(tester);
    await tester.enterText(field(1), 'qa-valid@example.com');
    await addRow(tester);
    await tester.enterText(field(2), 'QA Name Only');

    await send(tester);

    expect(repository.sent, isEmpty);
    expect(find.text(l10n.validationEmailRequired), findsOneWidget);
  });

  testWidgets('an untouched row is ignored and every filled row is sent', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.enterText(field(1), 'qa-one@example.com');
    await addRow(tester);
    await tester.enterText(field(3), 'qa-two@example.com');
    await addRow(tester);

    await send(tester);

    expect(
      repository.sent.single.map((invite) => invite['email']),
      ['qa-one@example.com', 'qa-two@example.com'],
    );
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('sending with only empty rows asks for an email', (
    tester,
  ) async {
    final l10n = await pumpScreen(tester);
    await send(tester);

    expect(repository.sent, isEmpty);
    expect(find.text(l10n.batchInviteAddEmailToSend), findsOneWidget);
    expect(find.text(l10n.validationEmailRequired), findsNothing);
  });
}

class _RecordingOnboardingRepository extends OnboardingRepository {
  _RecordingOnboardingRepository()
      : super(ApiClient(idTokenProvider: () async => null));

  final sent = <List<Map<String, dynamic>>>[];

  @override
  Future<BatchInviteResponse> sendBatchInvites(
    String babyId,
    List<Map<String, dynamic>> invites,
  ) async {
    sent.add(invites);
    return const BatchInviteResponse(results: []);
  }
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
