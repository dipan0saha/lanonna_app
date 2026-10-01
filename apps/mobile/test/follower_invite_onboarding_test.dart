import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/invitations/data/models/invitation_preview.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_routes.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:lanonna/features/onboarding/presentation/screens/follower/follower_carousel_screen.dart';
import 'package:lanonna/features/onboarding/presentation/screens/follower/onboarding_follower_invite_screen.dart';
import 'package:lanonna/features/onboarding/presentation/screens/shared/onboarding_wrong_email_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _preview = InvitationPreview(
  status: 'pending',
  babyName: 'Liam',
  inviterDisplayName: 'Alex',
  inviteeEmail: 'grandma@test.com',
  relationshipLabel: 'Grandma',
  invitedRole: 'follower',
  lifecycleStatus: 'expecting',
  expectedBirthDate: '2026-06-01',
);

Future<OnboardingCoordinator> _coordinatorWithPreview() async {
  SharedPreferences.setMockInitialValues({});
  final storage = OnboardingStorage(await SharedPreferences.getInstance());
  final coordinator = OnboardingCoordinator(
    storage: storage,
    repository: OnboardingRepository(ApiClient(idTokenProvider: () async => null)),
  );
  await coordinator.hydrate();
  await coordinator.bindInviteFromPreview('test-token', _preview);
  return coordinator;
}

void main() {
  testWidgets('follower invite landing shows inviter and baby name', (tester) async {
    final coordinator = await _coordinatorWithPreview();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: coordinator,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const OnboardingFollowerInviteScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Alex invited you to follow'), findsOneWidget);
    expect(find.text('Liam'), findsOneWidget);
    expect(find.text('Accept Invitation'), findsOneWidget);
  });

  testWidgets('follower carousel has five dot indicators', (tester) async {
    final coordinator = await _coordinatorWithPreview();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: coordinator,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const FollowerCarouselScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Welcome, you're in!"), findsOneWidget);
    expect(find.byType(FollowerCarouselScreen), findsOneWidget);
  });

  testWidgets('wrong email screen shows mismatch copy', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = OnboardingStorage(await SharedPreferences.getInstance());
    final coordinator = OnboardingCoordinator(
      storage: storage,
      repository: OnboardingRepository(ApiClient(idTokenProvider: () async => null)),
    );
    await coordinator.hydrate();

    final router = GoRouter(
      initialLocation:
          '${OnboardingRoutes.wrongEmail}?invitee=grandma@test.com&signed_in=other@test.com',
      routes: [
        GoRoute(
          path: OnboardingRoutes.wrongEmail,
          builder: (_, __) => const OnboardingWrongEmailScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: coordinator,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wrong account'), findsOneWidget);
    expect(find.textContaining('grandma@test.com'), findsOneWidget);
    expect(find.textContaining('other@test.com'), findsOneWidget);
  });
}
