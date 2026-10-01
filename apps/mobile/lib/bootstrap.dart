import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/auth/auth_repository.dart';
import 'core/router/router_refresh.dart';
import 'features/account/data/account_repository.dart';
import 'features/announcement/data/announcement_repository.dart';
import 'features/calendar/data/calendar_repository.dart';
import 'features/fun/data/fun_repository.dart';
import 'features/gallery/data/gallery_repository.dart';
import 'features/registry/data/registry_repository.dart';
import 'features/home/data/home_repository.dart';
import 'features/home/data/selected_baby_store.dart';
import 'features/invitations/data/invitations_repository.dart';
import 'features/onboarding/data/onboarding_repository.dart';
import 'features/onboarding/data/onboarding_storage.dart';
import 'features/onboarding/presentation/app_session.dart';
import 'features/onboarding/presentation/onboarding_coordinator.dart';
import 'main.dart';

Future<Widget> bootstrapLaNonnaApp() async {
  if (kDebugMode) {
    const email = String.fromEnvironment('DEV_AUTO_SIGN_IN_EMAIL');
    const password = String.fromEnvironment('DEV_AUTO_SIGN_IN_PASSWORD');
    if (email.isNotEmpty &&
        password.isNotEmpty &&
        FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
  }

  final onboardingStorage = await OnboardingStorage.create();
  final prefs = onboardingStorage.sharedPreferences;
  final authRepository = AuthRepository();
  final apiClient = ApiClient(idTokenProvider: authRepository.getIdToken);
  final onboardingRepository = OnboardingRepository(apiClient);
  final homeRepository = HomeRepository(apiClient);
  final galleryRepository = GalleryRepository(apiClient);
  final calendarRepository = CalendarRepository(apiClient);
  final registryRepository = RegistryRepository(apiClient);
  final funRepository = FunRepository(apiClient);
  final accountRepository = AccountRepository(apiClient);
  final announcementRepository = AnnouncementRepository(apiClient);
  final invitationsRepository = InvitationsRepository(apiClient);
  final coordinator = OnboardingCoordinator(
    storage: onboardingStorage,
    repository: onboardingRepository,
  );
  await coordinator.hydrate();
  final session = AppSession(
    repository: onboardingRepository,
    storage: onboardingStorage,
    coordinator: coordinator,
  );
  final selectedBabyStore = SelectedBabyStore(prefs);
  final routerRefresh = RouterRefreshListenable(
    authRepository: authRepository,
    coordinator: coordinator,
    session: session,
  );

  if (authRepository.currentUser != null) {
    await session.refreshFromApi();
  }

  return MultiProvider(
    providers: [
      Provider<AuthRepository>.value(value: authRepository),
      Provider<ApiClient>.value(value: apiClient),
      Provider<OnboardingRepository>.value(value: onboardingRepository),
      Provider<HomeRepository>.value(value: homeRepository),
      Provider<GalleryRepository>.value(value: galleryRepository),
      ChangeNotifierProvider<CalendarRepository>.value(
        value: calendarRepository,
      ),
      Provider<RegistryRepository>.value(value: registryRepository),
      Provider<FunRepository>.value(value: funRepository),
      Provider<AccountRepository>.value(value: accountRepository),
      Provider<AnnouncementRepository>.value(value: announcementRepository),
      Provider<InvitationsRepository>.value(value: invitationsRepository),
      Provider<SelectedBabyStore>.value(value: selectedBabyStore),
      ChangeNotifierProvider<OnboardingCoordinator>.value(value: coordinator),
      ChangeNotifierProvider<AppSession>.value(value: session),
    ],
    child: LaNonnaApp(routerRefresh: routerRefresh),
  );
}
