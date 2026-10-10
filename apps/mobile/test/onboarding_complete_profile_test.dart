import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_path.dart';
import 'package:lanonna/features/onboarding/presentation/app_session.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:lanonna/features/account/data/account_repository.dart';
import 'package:lanonna/features/onboarding/presentation/screens/onboarding_complete_profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptyDisplayNameAccountRepository extends _FakeAccountRepository {
  @override
  Future<AccountPayload> fetchAccount() async {
    final base = await super.fetchAccount();
    return AccountPayload(
      displayName: '',
      email: base.email,
      babies: base.babies,
      engagement: base.engagement,
      phone: base.phone,
      birthDate: base.birthDate,
      countryCode: base.countryCode,
      postalCode: base.postalCode,
    );
  }
}

class _FakeAccountRepository extends AccountRepository {
  _FakeAccountRepository() : super(ApiClient(idTokenProvider: () async => null));

  @override
  Future<AccountPayload> fetchAccount() async {
    return AccountPayload(
      displayName: 'R3 Follower',
      email: 'f@test.com',
      babies: const [],
      engagement: const UserEngagementStats(
        photosSquished: 0,
        eventsAttended: 0,
        itemsBought: 0,
        comments: 0,
      ),
      phone: '5550100',
      birthDate: '1990-04-12',
      countryCode: 'US',
      postalCode: '10001',
    );
  }
}

Future<({
  OnboardingCoordinator coordinator,
  OnboardingStorage storage,
  OnboardingRepository repository,
})> _fixturesForPath(OnboardingPath path) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final storage = OnboardingStorage(prefs);
  await storage.saveOnboardingPath(path);
  final repository = OnboardingRepository(ApiClient(idTokenProvider: () async => null));
  final coordinator = OnboardingCoordinator(
    storage: storage,
    repository: repository,
  );
  await coordinator.hydrate();
  return (coordinator: coordinator, storage: storage, repository: repository);
}

Widget _wrap(
  Widget child, {
  required OnboardingCoordinator coordinator,
  required OnboardingStorage storage,
  required OnboardingRepository repository,
  AccountRepository? accountRepository,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<OnboardingCoordinator>.value(value: coordinator),
      Provider<OnboardingRepository>.value(value: repository),
      Provider<AccountRepository>.value(
        value: accountRepository ?? _FakeAccountRepository(),
      ),
      ChangeNotifierProvider<AppSession>(
        create: (_) => AppSession(
          repository: repository,
          storage: storage,
          coordinator: coordinator,
        ),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light, home: child),
  );
}

void main() {
  testWidgets('owner complete profile shows relationship section', (tester) async {
    final fx = await _fixturesForPath(OnboardingPath.owner);
    await tester.pumpWidget(
      _wrap(
        const OnboardingCompleteProfileScreen(),
        coordinator: fx.coordinator,
        storage: fx.storage,
        repository: fx.repository,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Your relationship to baby'), findsOneWidget);
    expect(find.text('Mother'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('owner continue requires terms acceptance', (tester) async {
    final fx = await _fixturesForPath(OnboardingPath.owner);
    await tester.pumpWidget(
      _wrap(
        const OnboardingCompleteProfileScreen(),
        coordinator: fx.coordinator,
        storage: fx.storage,
        repository: fx.repository,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byKey(const Key('onboarding_first_name')), 'Test');
    await tester.enterText(find.byKey(const Key('onboarding_last_name')), 'User');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Please accept the terms to continue'), findsOneWidget);
  });

  testWidgets('prefills from server account when fields empty', (tester) async {
    final fx = await _fixturesForPath(OnboardingPath.follower);
    await tester.pumpWidget(
      _wrap(
        const OnboardingCompleteProfileScreen(),
        coordinator: fx.coordinator,
        storage: fx.storage,
        repository: fx.repository,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('onboarding_first_name')), findsOneWidget);
    final firstField = tester.widget<TextFormField>(
      find.descendant(
        of: find.byKey(const Key('onboarding_first_name')),
        matching: find.byType(TextFormField),
      ),
    );
    expect(firstField.controller?.text, 'R3');
  });

  testWidgets('name validation clears after fix without second submit', (tester) async {
    final fx = await _fixturesForPath(OnboardingPath.follower);
    await tester.pumpWidget(
      _wrap(
        const OnboardingCompleteProfileScreen(),
        coordinator: fx.coordinator,
        storage: fx.storage,
        repository: fx.repository,
        accountRepository: _EmptyDisplayNameAccountRepository(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('First name is required'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('onboarding_first_name')), 'Ada');
    await tester.pump();
    expect(find.text('First name is required'), findsNothing);
  });

  testWidgets('follower complete profile hides relationship section', (tester) async {
    final fx = await _fixturesForPath(OnboardingPath.follower);
    await tester.pumpWidget(
      _wrap(
        const OnboardingCompleteProfileScreen(),
        coordinator: fx.coordinator,
        storage: fx.storage,
        repository: fx.repository,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Your relationship to baby'), findsNothing);
  });
}
