import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/data/baby_list_cache.dart';
import 'package:lanonna/features/account/data/account_repository.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/home_summary_result.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/invitations/data/invitations_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake backend: one baby list, counts each request by path.
class _Api extends ApiClient {
  _Api() : super(idTokenProvider: () async => 'token');

  List<String> babyIds = ['baby-a', 'baby-b'];
  final requests = <String>[];

  int get babyListCalls =>
      requests.where((r) => r.startsWith('GET /v1/babies?')).length;

  Map<String, dynamic> _baby(String id) => {
    'id': id,
    'name': id,
    'role': 'owner',
    'lifecycle_status': 'expecting',
  };

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    requests.add('GET $path');
    if (path.startsWith('/v1/babies?')) {
      return {
        'items': [for (final id in babyIds) _baby(id)],
        'has_more': false,
      };
    }
    if (path.endsWith('/home-summary')) {
      return {'baby': _baby(path.split('/')[3])};
    }
    throw UnimplementedError(path);
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    requests.add('POST $path');
    if (path == '/v1/babies') return _baby('baby-new');
    if (path == '/v1/invitations/accept') {
      return {'baby_profile_id': 'baby-joined', 'role': 'follower'};
    }
    return {};
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    requests.add('PATCH $path');
    return _baby(path.split('/').last);
  }

  @override
  Future<void> deleteJson(String path, {Map<String, dynamic>? body}) async {
    requests.add('DELETE $path');
  }
}

void main() {
  late _Api api;
  late BabyListCache babyList;
  late HomeRepository home;
  late SelectedBabyStore store;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'selected_baby_id': 'baby-a'});
    store = SelectedBabyStore(await SharedPreferences.getInstance());
    api = _Api();
    now = DateTime(2026, 10, 18, 9);
    babyList = BabyListCache(api, currentUserId: () => 'uid', clock: () => now);
    home = HomeRepository(api, babyList: babyList, clock: () => now);
  });

  test('tabs and the shell resolving the baby at once make one request', () async {
    final results = await Future.wait([
      for (var i = 0; i < 6; i++) home.resolveSelectedBaby(store),
      home.babyById('baby-b'),
    ]);
    expect(api.babyListCalls, 1);
    expect(results.first?.id, 'baby-a');
    expect(results.last?.id, 'baby-b');

    await store.setSelectedBabyId('baby-b');
    expect((await home.resolveSelectedBaby(store))?.id, 'baby-b');
    expect(api.babyListCalls, 1, reason: 'a baby switch reuses the list');
  });

  test('an id missing from the cached list is refetched once', () async {
    await home.listBabies();
    api.babyIds = ['baby-a', 'baby-b', 'baby-c'];
    expect((await home.babyById('baby-c'))?.id, 'baby-c');
    expect(api.babyListCalls, 2);
    expect(await home.babyById('baby-gone'), isNull);
    expect(api.babyListCalls, 3);
  });

  test('pull-to-refresh refetches the list on the next read', () async {
    await home.listBabies();
    home.refreshBabiesOnNextRead();
    await home.listBabies();
    expect(api.babyListCalls, 2);
  });

  Future<void> expectInvalidates(Future<void> Function() change) async {
    await home.listBabies();
    final before = api.babyListCalls;
    await change();
    await home.listBabies();
    expect(api.babyListCalls, before + 1);
  }

  test('editing a baby invalidates the list', () async {
    await expectInvalidates(() => home.updateBaby('baby-a', name: 'Ada'));
  });

  test('creating a baby invalidates the list', () async {
    final onboarding = OnboardingRepository(api, babyList: babyList);
    await expectInvalidates(() => onboarding.createBaby(name: 'New'));
  });

  test('accepting an invitation invalidates the list', () async {
    final invitations = InvitationsRepository(api, babyList: babyList);
    await expectInvalidates(() => invitations.accept('token'));
  });

  test('removing a member and leaving a baby invalidate the list', () async {
    final account = AccountRepository(api, babyList: babyList);
    await expectInvalidates(() => account.removeMember('baby-a', 'uid-2'));
    await expectInvalidates(() => account.leaveBaby('baby-b'));
  });

  test('membership ended and joining invalidate the list', () async {
    await expectInvalidates(() async => home.invalidateBabies());
    await expectInvalidates(() => home.rememberJoinedBaby(store, 'baby-b'));
  });

  test('sign-out clears the list and the cached summaries', () async {
    await home.listBabies();
    await home.fetchHomeSummary('baby-a');
    home.clearCachedBabies();
    expect(home.cachedHomeSummary('baby-a'), isNull);
    await home.listBabies();
    expect(api.babyListCalls, 2);
  });

  test('the Home tab shown again reuses a recent summary', () async {
    String summaryCalls() =>
        api.requests.where((r) => r.endsWith('/home-summary')).length.toString();
    await home.fetchHomeSummary('baby-a');
    final again = await home.fetchHomeSummary(
      'baby-a',
      maxAge: HomeRepository.summaryFreshFor,
    );
    expect(again, isA<HomeSummaryLoaded>());
    expect(summaryCalls(), '1');

    now = now.add(HomeRepository.summaryFreshFor);
    await home.fetchHomeSummary('baby-a', maxAge: HomeRepository.summaryFreshFor);
    expect(summaryCalls(), '2');

    await home.fetchHomeSummary('baby-a');
    expect(summaryCalls(), '3', reason: 'without maxAge it always refetches');
  });
}
