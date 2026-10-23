import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/startup/signed_in_startup_prefetch.dart';
import 'package:lanonna/core/version/app_version_service.dart';
import 'package:lanonna/features/account/data/account_repository.dart';
import 'package:lanonna/features/account/data/notifications_repository.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/onboarding/data/models/onboarding_status.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/presentation/app_session.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TrackingApi extends ApiClient {
  _TrackingApi({this.offline = false})
    : super(idTokenProvider: () async => 'token', isOffline: () => offline);

  final bool offline;
  final startedAt = <String, int>{};
  final calls = <String, int>{};
  var versionDelay = Duration.zero;
  var authorizedDelay = Duration.zero;

  void _mark(String path) {
    if (offline) throw Exception('offline');
    final key = path.split('?').first;
    calls[key] = (calls[key] ?? 0) + 1;
    startedAt.putIfAbsent(key, () => DateTime.now().microsecondsSinceEpoch);
  }

  @override
  Future<Map<String, dynamic>> getJsonPublic(
    String path, {
    Duration? timeout,
  }) async {
    _mark('version');
    await Future<void>.delayed(versionDelay);
    return {'minimum_version': '0.0.1', 'store_url': 'https://example.com'};
  }

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool notifyMembershipEnded = true,
  }) async {
    _mark(path);
    await Future<void>.delayed(authorizedDelay);
    if (path == '/v1/onboarding/status') {
      return {
        'email_verified': true,
        'profile_complete': true,
        'has_owner_baby': true,
        'has_baby_membership': true,
        'owner_onboarding_completed': true,
        'needs_owner_onboarding': false,
        'can_access_main_app': true,
      };
    }
    if (path.startsWith('/v1/babies?')) {
      return {
        'items': [
          {
            'id': 'baby-1',
            'name': 'Test',
            'role': 'owner',
            'lifecycle_status': 'expecting',
          },
        ],
        'offset': 0,
        'limit': 100,
        'has_more': false,
      };
    }
    if (path.startsWith('/v1/babies/') && path.endsWith('/home-summary')) {
      return {
        'lifecycle_status': 'expecting',
        'family_insight': {
          'name_suggestion_count': 0,
          'vote_count': 0,
          'gender_totals': {'male': 0, 'female': 0},
        },
        'teasers': {'recent_photos': [], 'upcoming_events': []},
        'recent_activity': [],
      };
    }
    if (path == '/v1/me/account') {
      return {
        'profile': {'display_name': 'A'},
        'babies': [],
      };
    }
    if (path == '/v1/me/notifications/unread-count') {
      return {'count': 0};
    }
    throw UnimplementedError(path);
  }
}

Future<
  ({
    AppSession session,
    OnboardingCoordinator coordinator,
    OnboardingStorage storage,
  })
>
_sessionFixture(ApiClient api, SharedPreferences prefs) async {
  final storage = OnboardingStorage(prefs);
  final coordinator = OnboardingCoordinator(
    storage: storage,
    repository: OnboardingRepository(api),
  );
  await coordinator.hydrate();
  final session = AppSession(
    repository: OnboardingRepository(api),
    storage: storage,
    coordinator: coordinator,
    currentUserId: () => 'user-1',
  );
  return (session: session, coordinator: coordinator, storage: storage);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('signed-in startup prefetch', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'selected_baby_id': 'baby-1'});
      prefs = await SharedPreferences.getInstance();
    });

    test('version check and authorized reads start together', () async {
      final api = _TrackingApi()
        ..versionDelay = const Duration(milliseconds: 50)
        ..authorizedDelay = const Duration(milliseconds: 50);
      final f = await _sessionFixture(api, prefs);
      final versionService = AppVersionService(
        api,
        installedVersion: () async => '1.0.0',
      );

      final version = versionService.start();
      final prefetch = startSignedInStartupPrefetch(
        session: f.session,
        homeRepository: HomeRepository(api),
        selectedBabyStore: SelectedBabyStore(prefs),
        accountRepository: AccountRepository(api),
        notificationsRepository: NotificationsRepository(api),
      );
      await Future.wait([version, prefetch]);

      final versionAt = api.startedAt['version']!;
      for (final path in [
        '/v1/onboarding/status',
        '/v1/me/account',
        '/v1/me/notifications/unread-count',
        '/v1/babies/baby-1/home-summary',
      ]) {
        expect(
          (api.startedAt[path]! - versionAt).abs(),
          lessThan(40 * 1000),
          reason: '$path should start while the version check is in flight',
        );
      }
      expect(f.session.statusPhase, OnboardingStatusPhase.loaded);
    });

    test('readers that mount afterwards reuse the prefetched data', () async {
      final api = _TrackingApi();
      final f = await _sessionFixture(api, prefs);
      final homeRepo = HomeRepository(api);
      final store = SelectedBabyStore(prefs);
      final accountRepo = AccountRepository(api);
      final notificationsRepo = NotificationsRepository(api);

      await startSignedInStartupPrefetch(
        session: f.session,
        homeRepository: homeRepo,
        selectedBabyStore: store,
        accountRepository: accountRepo,
        notificationsRepository: notificationsRepo,
      );
      // What ShellChromeSync and HomeScreen read when they first mount.
      await Future.wait([
        accountRepo.ensureAccountLoaded(),
        notificationsRepo.refreshUnreadCount(
          maxAge: NotificationsRepository.unreadFreshFor,
        ),
        homeRepo.resolveSelectedBaby(store),
        homeRepo.fetchHomeSummary(
          'baby-1',
          maxAge: HomeRepository.summaryFreshFor,
          speculative: true,
        ),
      ]);

      expect(api.calls, {
        '/v1/onboarding/status': 1,
        '/v1/me/account': 1,
        '/v1/me/notifications/unread-count': 1,
        '/v1/babies': 1,
        '/v1/babies/baby-1/home-summary': 1,
      });
    });

    test(
      'an early Home load joins the in-flight speculative summary',
      () async {
        final api = _TrackingApi()
          ..authorizedDelay = const Duration(milliseconds: 20);
        final homeRepo = HomeRepository(api);

        await Future.wait([
          homeRepo.fetchHomeSummary('baby-1', speculative: true),
          homeRepo.fetchHomeSummary(
            'baby-1',
            maxAge: HomeRepository.summaryFreshFor,
            speculative: true,
          ),
        ]);
        expect(api.calls['/v1/babies/baby-1/home-summary'], 1);

        // A refresh after a mutation never joins an older request.
        await Future.wait([
          homeRepo.fetchHomeSummary('baby-1', speculative: true),
          homeRepo.fetchHomeSummary('baby-1'),
        ]);
        expect(api.calls['/v1/babies/baby-1/home-summary'], 3);
      },
    );

    test(
      'offline keeps cached onboarding; version does not hard-block',
      () async {
        final api = _TrackingApi(offline: true);
        final f = await _sessionFixture(api, prefs);
        const cached = OnboardingStatus(
          emailVerified: true,
          profileComplete: true,
          hasOwnerBaby: true,
          hasBabyMembership: true,
          ownerOnboardingCompleted: true,
          needsOwnerOnboarding: false,
          canAccessMainApp: true,
        );
        await f.storage.saveCachedOnboardingStatus('user-1', cached);
        final versionService = AppVersionService(
          api,
          installedVersion: () async => '1.0.0',
        );
        await Future.wait([
          versionService.start(),
          startSignedInStartupPrefetch(
            session: f.session,
            homeRepository: HomeRepository(api),
            selectedBabyStore: SelectedBabyStore(prefs),
            accountRepository: AccountRepository(api),
            notificationsRepository: NotificationsRepository(api),
          ),
        ]);
        expect(f.session.statusPhase, OnboardingStatusPhase.loaded);
        expect(f.session.statusStale, isTrue);
        expect(versionService.blockRequirement, isNull);
      },
    );
  });
}
