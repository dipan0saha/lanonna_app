import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/calendar/domain/calendar_routes.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/calendar/presentation/calendar_upcoming_screen.dart';
import '../../features/calendar/presentation/event_ai_suggestions_screen.dart';
import '../../features/calendar/presentation/event_detail_screen.dart';
import '../../features/calendar/presentation/event_form_screen.dart';
import '../../features/fun/presentation/fun_screen.dart';
import '../../features/gallery/domain/gallery_routes.dart';
import '../../features/gallery/presentation/gallery_screen.dart';
import '../../features/gallery/presentation/photo_detail_screen.dart';
import '../../features/home/domain/app_routes.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/presentation/home_activity_screen.dart';
import '../../features/invitations/presentation/batch_invite_screen.dart';
import '../../features/onboarding/domain/onboarding_routes.dart';
import '../../features/onboarding/presentation/app_session.dart';
import '../../features/onboarding/presentation/screens/onboarding_batch_invite_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_complete_profile_screen.dart';
import '../../features/legal/presentation/legal_document_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_create_baby_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_email_verify_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_first_moment_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_login_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_signup_screen.dart';
import '../../features/invitations/presentation/invite_accept_bootstrap_screen.dart';
import '../../features/onboarding/presentation/screens/coowner/onboarding_coowner_invite_screen.dart';
import '../../features/onboarding/presentation/screens/coowner/onboarding_coowner_welcome_screen.dart';
import '../../features/onboarding/presentation/screens/follower/follower_carousel_screen.dart';
import '../../features/onboarding/presentation/screens/follower/onboarding_confirm_relationship_screen.dart';
import '../../features/onboarding/presentation/screens/follower/onboarding_follower_invite_screen.dart';
import '../../features/onboarding/presentation/screens/shared/onboarding_wrong_email_screen.dart';
import '../../features/onboarding/presentation/screens/owner_carousel_screen.dart';
import '../../features/account/presentation/account_edit_screen.dart';
import '../../features/account/presentation/baby_data_export_screen.dart';
import '../../features/account/presentation/delete_account_screen.dart';
import '../../features/account/presentation/account_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/account/presentation/notification_preferences_screen.dart';
import '../../features/account/presentation/notifications_inbox_screen.dart';
import '../../features/baby/domain/create_baby_mode.dart';
import '../../features/baby/presentation/create_baby_screen.dart';
import '../../features/account/presentation/baby_edit_screen.dart';
import '../../features/account/presentation/followers_screen.dart';
import '../../features/announcement/presentation/announcement_card_screen.dart';
import '../../features/announcement/presentation/announcement_create_screen.dart';
import '../../features/registry/domain/registry_routes.dart';
import '../../features/registry/presentation/registry_ai_suggestions_screen.dart';
import '../../features/registry/presentation/registry_item_form_screen.dart';
import '../../features/registry/presentation/registry_screen.dart';
import '../../features/search/presentation/global_search_screen.dart';
import '../../features/shell/main_shell_screen.dart';
import '../auth/auth_repository.dart';
import 'router_refresh.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter(
  RouterRefreshListenable refreshListenable, {
  String? initialLocation,
}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: initialLocation ?? OnboardingRoutes.ownerCarousel,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final auth = context.read<AuthRepository>();
      final session = context.read<AppSession>();
      final user = auth.currentUser;
      return session.redirectFor(
        isSignedIn: user != null,
        emailVerified: user?.emailVerified ?? false,
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: OnboardingRoutes.roleSelection,
        redirect: (_, __) => OnboardingRoutes.ownerCarousel,
      ),
      GoRoute(
        path: '/login',
        redirect: (_, __) => OnboardingRoutes.login,
      ),
      GoRoute(
        path: OnboardingRoutes.ownerCarousel,
        builder: (context, state) => const OwnerCarouselScreen(),
      ),
      GoRoute(
        path: OnboardingRoutes.signup,
        builder: (context, state) => const OnboardingSignupScreen(),
      ),
      GoRoute(
        path: OnboardingRoutes.login,
        builder: (context, state) => const OnboardingLoginScreen(),
      ),
      GoRoute(
        path: OnboardingRoutes.emailVerify,
        builder: (context, state) => const OnboardingEmailVerifyScreen(),
      ),
      GoRoute(
        path: OnboardingRoutes.completeProfile,
        builder: (context, state) => const OnboardingCompleteProfileScreen(),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (context, state) =>
            const LegalDocumentScreen(kind: LegalDocumentKind.terms),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (context, state) =>
            const LegalDocumentScreen(kind: LegalDocumentKind.privacy),
      ),
      GoRoute(
        path: OnboardingRoutes.ownerCreateBaby,
        builder: (context, state) => const OnboardingCreateBabyScreen(),
      ),
      GoRoute(
        path: OnboardingRoutes.ownerFirstMoment,
        builder: (context, state) => const OnboardingFirstMomentScreen(),
      ),
      GoRoute(
        path: OnboardingRoutes.ownerInvite,
        builder: (context, state) => const OnboardingBatchInviteScreen(),
      ),
      GoRoute(
        path: OnboardingRoutes.inviteAccept,
        builder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return InviteAcceptBootstrapScreen(token: token);
        },
      ),
      GoRoute(
        path: OnboardingRoutes.followerInvite,
        builder: (context, state) => const OnboardingFollowerInviteScreen(),
      ),
      GoRoute(
        path: OnboardingRoutes.coOwnerInvite,
        builder: (context, state) => const OnboardingCoOwnerInviteScreen(),
      ),
      GoRoute(
        path: OnboardingRoutes.confirmRelationship,
        builder: (context, state) => const OnboardingConfirmRelationshipScreen(),
      ),
      GoRoute(
        path: OnboardingRoutes.followerCarousel,
        builder: (context, state) => const FollowerCarouselScreen(),
      ),
      GoRoute(
        path: OnboardingRoutes.coOwnerWelcome,
        builder: (context, state) => const OnboardingCoOwnerWelcomeScreen(),
      ),
      GoRoute(
        path: OnboardingRoutes.wrongEmail,
        builder: (context, state) => const OnboardingWrongEmailScreen(),
      ),
      GoRoute(
        path: '/profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/account/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AccountEditScreen(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/account/notification-preferences',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationPreferencesScreen(),
      ),
      GoRoute(
        path: '/account/export',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BabyDataExportScreen(),
      ),
      GoRoute(
        path: '/account/delete',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: '/notifications/inbox',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsInboxScreen(),
      ),
      GoRoute(
        path: '/search',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GlobalSearchScreen(),
      ),
      GoRoute(
        path: '/baby/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateBabyScreen(mode: CreateBabyMode.inApp),
      ),
      GoRoute(
        path: '/baby/:babyId/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => BabyEditScreen(
          babyId: state.pathParameters['babyId']!,
        ),
      ),
      GoRoute(
        path: '/baby/:babyId/followers',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => FollowersScreen(
          babyId: state.pathParameters['babyId']!,
        ),
      ),
      GoRoute(
        path: '/baby/:babyId/announcement',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => AnnouncementCardScreen(
          babyId: state.pathParameters['babyId']!,
        ),
      ),
      GoRoute(
        path: '/baby/:babyId/announcement/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => AnnouncementCreateScreen(
          babyId: state.pathParameters['babyId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.inviteFamily,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BatchInviteScreen(mode: BatchInviteMode.fromHome),
      ),
      GoRoute(
        path: '/home/activity',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final babyId = state.uri.queryParameters['babyId'] ?? '';
          return HomeActivityScreen(babyId: babyId);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: GalleryRoutes.gallery,
                builder: (context, state) => const GalleryScreen(),
                routes: [
                  GoRoute(
                    path: 'recent',
                    builder: (context, state) =>
                        const GalleryScreen(mode: GalleryViewMode.recent),
                  ),
                  GoRoute(
                    path: 'favorites',
                    builder: (context, state) =>
                        const GalleryScreen(mode: GalleryViewMode.favorites),
                  ),
                  GoRoute(
                    path: 'photo/:photoId',
                    builder: (context, state) => PhotoDetailScreen(
                      photoId: state.pathParameters['photoId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: CalendarRoutes.calendar,
                builder: (context, state) => const CalendarScreen(),
                routes: [
                  GoRoute(
                    path: 'event/create',
                    builder: (context, state) {
                      final prefill = state.extra;
                      if (prefill is EventFormPrefill) {
                        return EventFormScreen(
                          initialTitle: prefill.title,
                          initialDescription: prefill.description,
                          initialCatalogSuggestionId: prefill.catalogSuggestionId,
                          initialDate: prefill.initialDate,
                        );
                      }
                      return const EventFormScreen();
                    },
                  ),
                  GoRoute(
                    path: 'event/:eventId',
                    builder: (context, state) => EventDetailScreen(
                      eventId: state.pathParameters['eventId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => EventFormScreen(
                          eventId: state.pathParameters['eventId'],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'ai-suggestions',
                    builder: (context, state) =>
                        const EventAiSuggestionsScreen(),
                  ),
                  GoRoute(
                    path: 'upcoming',
                    builder: (context, state) => const CalendarUpcomingScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RegistryRoutes.registry,
                builder: (context, state) => const RegistryScreen(),
                routes: [
                  GoRoute(
                    path: 'item/create',
                    builder: (context, state) {
                      final prefill = state.extra;
                      if (prefill is RegistryItemFormPrefill) {
                        return RegistryItemFormScreen(
                          initialName: prefill.name,
                          initialDescription: prefill.description,
                          initialCatalogSuggestionId: prefill.catalogSuggestionId,
                        );
                      }
                      return const RegistryItemFormScreen();
                    },
                  ),
                  GoRoute(
                    path: 'item/:itemId',
                    redirect: (context, state) =>
                        '/registry/item/${state.pathParameters['itemId']}/edit',
                  ),
                  GoRoute(
                    path: 'item/:itemId/edit',
                    builder: (context, state) => RegistryItemFormScreen(
                      itemId: state.pathParameters['itemId'],
                    ),
                  ),
                  GoRoute(
                    path: 'ai-suggestions',
                    builder: (context, state) =>
                        const RegistryAiSuggestionsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.gamification,
                builder: (context, state) => const FunScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
