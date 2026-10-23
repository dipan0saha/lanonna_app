import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/auth/auth_repository.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/invitations/domain/invitation_status.dart';
import 'package:lanonna/features/invitations/data/models/invitation_preview.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/presentation/app_session.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:lanonna/features/onboarding/presentation/utils/invite_flow_navigation.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedInAuth extends AuthRepository {
  _SignedInAuth() : super(firebaseAuth: _FakeFirebaseAuth());

  @override
  User? get currentUser => _FakeUser();
}

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {}

class _FakeUser extends Fake implements User {}

class _TrackingHome extends HomeRepository {
  _TrackingHome() : super(ApiClient(idTokenProvider: () async => 't'));

  String? rememberedBabyId;

  @override
  Future<void> rememberJoinedBaby(
    SelectedBabyStore store,
    String babyId,
  ) async {
    rememberedBabyId = babyId;
    await store.setSelectedBabyId(babyId);
  }
}

void main() {
  testWidgets('openAcceptedInvitePreview goes home without pending token', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = OnboardingStorage(await SharedPreferences.getInstance());
    final coordinator = OnboardingCoordinator(
      storage: storage,
      repository: OnboardingRepository(
        ApiClient(idTokenProvider: () async => 't'),
      ),
    );
    await coordinator.hydrate();
    await coordinator.bindInviteFromPreview(
      'cleared-token',
      const InvitationPreview(
        status: InvitationStatus.accepted,
        babyName: 'Luna',
        inviterDisplayName: 'Alex',
        inviteeEmail: 'owner@test.com',
        relationshipLabel: 'Parent',
        invitedRole: 'follower',
        babyProfileId: 'luna-baby-id',
        lifecycle: BabyLifecycle.born,
      ),
    );
    await coordinator.setPendingInviteToken(null);

    final home = _TrackingHome();
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    final session = AppSession(
      repository: OnboardingRepository(
        ApiClient(idTokenProvider: () async => 't'),
      ),
      storage: storage,
      coordinator: coordinator,
      currentUserId: () => 'user-1',
    );

    late GoRouter router;
    router = GoRouter(
      initialLocation: '/invite',
      routes: [
        GoRoute(
          path: '/invite',
          builder: (context, state) => MultiProvider(
            providers: [
              Provider<AuthRepository>.value(value: _SignedInAuth()),
              ChangeNotifierProvider<OnboardingCoordinator>.value(
                value: coordinator,
              ),
              Provider<HomeRepository>.value(value: home),
              ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
              ChangeNotifierProvider<AppSession>.value(value: session),
            ],
            child: Scaffold(
              body: ElevatedButton(
                onPressed: () => openAcceptedInvitePreview(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home reached')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Home reached'), findsOneWidget);
    expect(home.rememberedBabyId, 'luna-baby-id');
  });
}
