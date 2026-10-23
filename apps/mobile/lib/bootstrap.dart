import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/app_check/app_check_token_source.dart';
import 'core/deep_links/app_link_bootstrap.dart';
import 'core/deep_links/auth_action_app_link.dart';
import 'core/deep_links/invite_app_link.dart';
import 'core/auth/auth_repository.dart';
import 'core/auth/biometric_credential_repository.dart';
import 'core/auth/biometric_sign_in_service.dart';
import 'core/auth/biometric_sign_in_store.dart';
import 'core/auth/membership_access_handler.dart';
import 'core/auth/session_cleanup.dart';
import 'core/auth/user_deleted_session_handler.dart';
import 'core/data/baby_list_cache.dart';
import 'core/data/parallel_requests.dart';
import 'core/network/connectivity_service.dart';
import 'core/observability/crash_reporting_bootstrap.dart';
import 'core/observability/crashlytics_dev_tools.dart';
import 'core/router/router_refresh.dart';
import 'core/startup/signed_in_startup_prefetch.dart';
import 'core/version/app_version_service.dart';
import 'features/account/data/account_identity_store.dart';
import 'features/account/data/account_repository.dart';
import 'features/account/data/notifications_repository.dart';
import 'features/announcement/data/announcement_repository.dart';
import 'features/calendar/data/calendar_repository.dart';
import 'features/fun/data/fun_repository.dart';
import 'core/media/event_cover_uploader.dart';
import 'features/gallery/data/gallery_repository.dart';
import 'features/registry/data/registry_repository.dart';
import 'features/home/data/home_refresh_signal.dart';
import 'features/home/data/home_repository.dart';
import 'features/home/data/selected_baby_store.dart';
import 'features/invitations/data/invitations_repository.dart';
import 'features/invitations/presentation/invite_flow_state.dart';
import 'features/onboarding/data/onboarding_repository.dart';
import 'features/onboarding/data/onboarding_storage.dart';
import 'features/onboarding/presentation/app_session.dart';
import 'features/onboarding/presentation/onboarding_coordinator.dart';
import 'app.dart';

/// Builds the app's object graph. Local reads (preferences, connectivity, the
/// cold-start link) run together; nothing here waits on the network.
Future<Widget> bootstrapLaNonnaApp({
  required AppCheckTokenSource appCheck,
}) async {
  if (kDebugMode) {
    const email = String.fromEnvironment('DEV_AUTO_SIGN_IN_EMAIL');
    const password = String.fromEnvironment('DEV_AUTO_SIGN_IN_PASSWORD');
    if (email.isNotEmpty &&
        password.isNotEmpty &&
        FirebaseAuth.instance.currentUser == null) {
      await appCheck.activated;
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
  }

  final authRepository = AuthRepository();
  await startCrashReporting(authRepository: authRepository);
  scheduleCrashlyticsTestCrashOnStartIfRequested();
  // A signed-in launch makes authorized requests right away; start the
  // App Check read now so a first-launch attestation overlaps start-up.
  if (authRepository.currentUser != null) appCheck.prefetch();
  final connectivityService = ConnectivityService();
  final (onboardingStorage, _, coldStartUri) = await waitAll3(
    OnboardingStorage.create(),
    connectivityService.init(),
    readColdStartAppLinkUri(),
  );
  final prefs = onboardingStorage.sharedPreferences;
  late final OnboardingCoordinator coordinator;
  late final SessionCleanup sessionCleanup;
  final apiClient = ApiClient(
    idTokenProvider: authRepository.getIdToken,
    appCheckTokenProvider: appCheck.token,
    isOffline: () => !connectivityService.isOnline,
    onSessionInvalidated: (_) => handleUserDeletedSession(
      authRepository: authRepository,
      sessionCleanup: sessionCleanup,
    ),
  );
  final biometricSignInService = BiometricSignInService(
    credentials: BiometricCredentialRepository(apiClient),
    store: BiometricSignInStore(prefs),
    authRepository: authRepository,
  )..bindAuthState();
  // One baby list for the whole app; repositories that change memberships
  // invalidate it.
  final babyList = BabyListCache(
    apiClient,
    currentUserId: () => authRepository.currentUser?.uid,
  );
  final onboardingRepository = OnboardingRepository(
    apiClient,
    babyList: babyList,
  );
  final homeRepository = HomeRepository(apiClient, babyList: babyList);
  final galleryRepository = GalleryRepository(apiClient);
  final eventCoverUploader = ApiEventCoverUploader(apiClient);
  final calendarRepository = CalendarRepository(apiClient);
  final registryRepository = RegistryRepository(apiClient);
  final funRepository = FunRepository(apiClient);
  final accountRepository = AccountRepository(
    apiClient,
    babyList: babyList,
    identityStore: AccountIdentityStore(prefs),
    currentUserId: () => authRepository.currentUser?.uid,
  );
  final notificationsRepository = NotificationsRepository(apiClient);
  final announcementRepository = AnnouncementRepository(apiClient);
  final invitationsRepository = InvitationsRepository(
    apiClient,
    babyList: babyList,
  );
  coordinator = OnboardingCoordinator(
    storage: onboardingStorage,
    repository: onboardingRepository,
  );
  await coordinator.hydrate();
  final inviteFlowState = InviteFlowState();
  final session = AppSession(
    repository: onboardingRepository,
    storage: onboardingStorage,
    coordinator: coordinator,
    currentUserId: () => authRepository.currentUser?.uid,
  );
  session.bindConnectivity(connectivityService);
  final selectedBabyStore = SelectedBabyStore(prefs);
  sessionCleanup = SessionCleanup(
    coordinator: coordinator,
    homeRepository: homeRepository,
    selectedBabyStore: selectedBabyStore,
    inviteFlowState: inviteFlowState,
    accountRepository: accountRepository,
    notificationsRepository: notificationsRepository,
    galleryRepository: galleryRepository,
    calendarRepository: calendarRepository,
  );
  final homeRefreshSignal = HomeRefreshSignal();
  apiClient.registerMembershipEndedHandler(
    (exception) => handleMembershipEnded(
      homeRepository: homeRepository,
      store: selectedBabyStore,
      signal: homeRefreshSignal,
      exception: exception,
    ),
  );
  final routerRefresh = RouterRefreshListenable(
    authRepository: authRepository,
    coordinator: coordinator,
    session: session,
  );

  final appVersionService = AppVersionService();
  appVersionService.ensureStarted(apiClient);
  if (authRepository.currentUser != null) {
    startSignedInStartupPrefetch(
      session: session,
      homeRepository: homeRepository,
      selectedBabyStore: selectedBabyStore,
      accountRepository: accountRepository,
      notificationsRepository: notificationsRepository,
    );
  }

  final initialInviteLocation = coldStartUri != null
      ? inviteAppLinkToRouterLocation(coldStartUri)
      : null;
  final Uri? initialEmailVerifyUri;
  if (coldStartUri != null &&
      initialInviteLocation == null &&
      parseEmailVerifyActionLink(coldStartUri) != null) {
    initialEmailVerifyUri = coldStartUri;
  } else {
    initialEmailVerifyUri = null;
  }

  return MultiProvider(
    providers: [
      Provider<AuthRepository>.value(value: authRepository),
      Provider<BiometricSignInService>.value(value: biometricSignInService),
      Provider<SessionCleanup>.value(value: sessionCleanup),
      Provider<ApiClient>.value(value: apiClient),
      ChangeNotifierProvider<AppVersionService>.value(value: appVersionService),
      Provider<EventCoverUploader>.value(value: eventCoverUploader),
      Provider<OnboardingRepository>.value(value: onboardingRepository),
      Provider<HomeRepository>.value(value: homeRepository),
      ChangeNotifierProvider<GalleryRepository>.value(value: galleryRepository),
      ChangeNotifierProvider<CalendarRepository>.value(
        value: calendarRepository,
      ),
      Provider<RegistryRepository>.value(value: registryRepository),
      Provider<FunRepository>.value(value: funRepository),
      Provider<AccountRepository>.value(value: accountRepository),
      ChangeNotifierProvider<NotificationsRepository>.value(
        value: notificationsRepository,
      ),
      Provider<AnnouncementRepository>.value(value: announcementRepository),
      Provider<InvitationsRepository>.value(value: invitationsRepository),
      ChangeNotifierProvider<SelectedBabyStore>.value(value: selectedBabyStore),
      Provider<HomeRefreshSignal>.value(value: homeRefreshSignal),
      ChangeNotifierProvider<ConnectivityService>.value(
        value: connectivityService,
      ),
      ChangeNotifierProvider<OnboardingCoordinator>.value(value: coordinator),
      ChangeNotifierProvider<InviteFlowState>.value(value: inviteFlowState),
      ChangeNotifierProvider<AppSession>.value(value: session),
    ],
    child: LaNonnaApp(
      routerRefresh: routerRefresh,
      initialInviteLocation: initialInviteLocation,
      initialEmailVerifyUri: initialEmailVerifyUri,
    ),
  );
}
