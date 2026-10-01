import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_routes.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:lanonna/features/onboarding/presentation/screens/onboarding_login_screen.dart';
import 'package:lanonna/features/onboarding/presentation/widgets/onboarding_fields.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpLogin(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final storage = OnboardingStorage(await SharedPreferences.getInstance());
  final coordinator = OnboardingCoordinator(
    storage: storage,
    repository: OnboardingRepository(
      ApiClient(idTokenProvider: () async => null),
    ),
  );
  await coordinator.hydrate();

  final router = GoRouter(
    initialLocation: OnboardingRoutes.login,
    routes: [
      GoRoute(
        path: OnboardingRoutes.login,
        builder: (_, __) => const OnboardingLoginScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    ChangeNotifierProvider<OnboardingCoordinator>.value(
      value: coordinator,
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login matches signup stack: welcome, google, divider, sign in', (tester) async {
    await _pumpLogin(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.textContaining('family space'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('or sign in with email'), findsOneWidget);
    expect(find.byKey(const Key('onboarding_login_email')), findsOneWidget);
    expect(find.byKey(const Key('sign_in_button')), findsOneWidget);
    expect(find.byType(OnboardingBottomLink), findsOneWidget);
  });
}
