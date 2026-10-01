import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_routes.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:lanonna/features/onboarding/presentation/screens/owner_carousel_screen.dart';
import 'package:lanonna/features/onboarding/presentation/widgets/owner_carousel_slides.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpCarousel(WidgetTester tester) async {
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
    initialLocation: OnboardingRoutes.ownerCarousel,
    routes: [
      GoRoute(
        path: OnboardingRoutes.ownerCarousel,
        builder: (_, __) => const OwnerCarouselScreen(),
      ),
      GoRoute(
        path: OnboardingRoutes.signup,
        builder: (_, __) => const Scaffold(body: Text('signup')),
      ),
      GoRoute(
        path: OnboardingRoutes.login,
        builder: (_, __) => const Scaffold(body: Text('login')),
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
  test('ownerCarouselSlide returns four distinct slides', () {
    expect(ownerCarouselSlideCount, 4);
    expect(ownerCarouselSlide(0).$1, contains('private place'));
    expect(ownerCarouselSlide(3).$1, 'Never lose a moment');
  });

  testWidgets('owner carousel shows Next then Get started on last slide',
      (tester) async {
    await _pumpCarousel(tester);

    expect(find.byKey(const Key('owner_carousel_next')), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    for (var i = 0; i < ownerCarouselSlideCount - 1; i++) {
      await tester.tap(find.byKey(const Key('owner_carousel_next')));
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const Key('owner_carousel_get_started')), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Get started'), findsOneWidget);
  });
}
