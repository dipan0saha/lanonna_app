import 'package:flutter/material.dart';
import 'package:lanonna/features/invitations/domain/invitation_status.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
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
import 'package:lanonna/features/invitations/presentation/invite_flow_state.dart';
import 'package:lanonna/features/onboarding/presentation/screens/shared/onboarding_wrong_email_screen.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _preview = InvitationPreview(
  status: InvitationStatus.pending,
  babyName: 'Liam',
  inviterDisplayName: 'Alex',
  inviteeEmail: 'grandma@test.com',
  relationshipLabel: 'Grandma',
  invitedRole: 'follower',
  lifecycle: BabyLifecycle.expecting,
  expectedBirthDate: '2026-06-01',
);

Future<OnboardingCoordinator> _coordinatorWithPreview() async {
  SharedPreferences.setMockInitialValues({});
  final storage = OnboardingStorage(await SharedPreferences.getInstance());
  final coordinator = OnboardingCoordinator(
    storage: storage,
    repository: OnboardingRepository(
      ApiClient(idTokenProvider: () async => null),
    ),
  );
  await coordinator.hydrate();
  await coordinator.bindInviteFromPreview('test-token', _preview);
  return coordinator;
}

void main() {
  testWidgets('follower invite landing shows inviter and baby name', (
    tester,
  ) async {
    final coordinator = await _coordinatorWithPreview();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: coordinator,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: const OnboardingFollowerInviteScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Alex invited you to follow'), findsOneWidget);
    expect(find.text('Liam'), findsOneWidget);
    expect(find.text('Accept Invitation'), findsOneWidget);
    expect(find.bySemanticsIdentifier('invite_landing_accept'), findsOneWidget);
  });

  testWidgets('accepted invite preview offers Open instead of Accept', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = OnboardingStorage(await SharedPreferences.getInstance());
    final coordinator = OnboardingCoordinator(
      storage: storage,
      repository: OnboardingRepository(
        ApiClient(idTokenProvider: () async => null),
      ),
    );
    await coordinator.hydrate();
    await coordinator.bindInviteFromPreview(
      'test-token',
      const InvitationPreview(
        status: InvitationStatus.accepted,
        babyName: 'Liam',
        inviterDisplayName: 'Alex',
        inviteeEmail: 'grandma@test.com',
        relationshipLabel: 'Grandma',
        invitedRole: 'follower',
        babyProfileId: 'baby-1',
        lifecycle: BabyLifecycle.expecting,
        expectedBirthDate: '2026-06-01',
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: coordinator,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: const OnboardingFollowerInviteScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're already a member"), findsOneWidget);
    expect(find.text('Liam'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Accept Invitation'), findsNothing);
  });

  testWidgets('follower carousel has five dot indicators', (tester) async {
    final coordinator = await _coordinatorWithPreview();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: coordinator,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
      repository: OnboardingRepository(
        ApiClient(idTokenProvider: () async => null),
      ),
    );
    await coordinator.hydrate();

    final inviteFlowState = InviteFlowState();
    inviteFlowState.setEmailMismatch(
      inviteeEmail: 'grandma@test.com',
      signedInEmail: 'other@test.com',
    );

    final router = GoRouter(
      initialLocation: OnboardingRoutes.wrongEmail,
      routes: [
        GoRoute(
          path: OnboardingRoutes.wrongEmail,
          builder: (_, __) => const OnboardingWrongEmailScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: coordinator),
          ChangeNotifierProvider.value(value: inviteFlowState),
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
    expect(find.text('Wrong account'), findsOneWidget);
    expect(find.textContaining('grandma@test.com'), findsOneWidget);
    expect(find.textContaining('other@test.com'), findsOneWidget);
  });
}
