import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_path.dart';
import 'package:lanonna/features/onboarding/presentation/app_session.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:lanonna/features/onboarding/presentation/screens/onboarding_complete_profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<OnboardingCoordinator>.value(value: coordinator),
      Provider<OnboardingRepository>.value(value: repository),
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
