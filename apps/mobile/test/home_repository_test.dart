import 'dart:async';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/api/api_exception.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/home_summary_result.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('fetchHomeSummary returns HomeSummaryLoaded on 200', () async {
    final repo = HomeRepository(_SuccessApi());
    final result = await repo.fetchHomeSummary('baby-1');

    expect(result, isA<HomeSummaryLoaded>());
    final loaded = result as HomeSummaryLoaded;
    expect(loaded.summary.lifecycle, BabyLifecycle.expecting);
    expect(loaded.summary.teasers?.upcomingEvents, isEmpty);
    expect(loaded.summary.recentActivity, isEmpty);
  });

  test('listBabies falls back to cache when network fails', () async {
    final api = _FlakyBabiesApi();
    final repo = HomeRepository(api, currentUserId: () => 'user-1');
    final online = await repo.listBabies();
    expect(online, hasLength(2));
    api.failRequests = true;
    final offline = await repo.listBabies();
    expect(offline, online);
  });

  test('resolveSelectedBaby uses first baby when none selected', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    final repo = HomeRepository(_BabiesApi());
    final baby = await repo.resolveSelectedBaby(store);
    expect(baby?.id, 'baby-a');
    expect(baby?.name, 'Alpha');
    expect(store.selectedBabyId, 'baby-a');
    expect(store.selectedBabyName, 'Alpha');
  });

  test('in-flight resolve does not overwrite a newer selection', () async {
    SharedPreferences.setMockInitialValues({'selected_baby_id': 'baby-a'});
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    final api = _GatedBabiesApi();
    final repo = HomeRepository(api);
    final pending = repo.resolveSelectedBaby(store);
    await api.started.future;
    await store.setSelectedBabyId('baby-b');
    api.release();
    final baby = await pending;
    expect(store.selectedBabyId, 'baby-b');
    expect(baby?.id, 'baby-b');
  });

  test('resolveSelectedBaby persists when stored id is stale', () async {
    SharedPreferences.setMockInitialValues({'selected_baby_id': 'gone'});
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    final repo = HomeRepository(_BabiesApi());
    final baby = await repo.resolveSelectedBaby(store);
    expect(baby?.id, 'baby-a');
    expect(store.selectedBabyId, 'baby-a');
  });

  test('resolveOwnerBaby prefers selected when owner', () async {
    SharedPreferences.setMockInitialValues({'selected_baby_id': 'baby-b'});
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    final repo = HomeRepository(_BabiesApi());
    final baby = await repo.resolveOwnerBaby(store);
    expect(baby?.id, 'baby-b');
  });

  test('babyById returns membership for route baby id', () async {
    final repo = HomeRepository(_BabiesApi());
    final baby = await repo.babyById('baby-b');
    expect(baby?.id, 'baby-b');
    expect(baby?.role, 'owner');
    expect(await repo.babyById('missing'), isNull);
  });

  test('resolveOwnerBaby skips follower-only selection', () async {
    SharedPreferences.setMockInitialValues({'selected_baby_id': 'baby-f'});
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    final repo = HomeRepository(_MixedBabiesApi());
    final baby = await repo.resolveOwnerBaby(store);
    expect(baby?.id, 'baby-o');
  });

  test('fetchHomeSummary returns HomeSummaryFailed on API error', () async {
    final repo = HomeRepository(_FailingApi());
    final result = await repo.fetchHomeSummary('baby-1');

    expect(result, isA<HomeSummaryFailed>());
    final failed = result as HomeSummaryFailed;
    expect(failed.error, isA<ApiException>());
    expect((failed.error as ApiException).statusCode, 500);
  });

  test('fetchHomeSummary caches and serves stale on network failure', () async {
    final api = _FlakySummaryApi();
    final repo = HomeRepository(api);
    final online = await repo.fetchHomeSummary('baby-1');
    expect(online, isA<HomeSummaryLoaded>());
    expect(repo.cachedHomeSummary('baby-1')?.lifecycle, BabyLifecycle.expecting);

    api.failRequests = true;
    final offline = await repo.fetchHomeSummary('baby-1');
    expect(offline, isA<HomeSummaryLoaded>());
  });

  test('summary cache survives switching to another baby', () async {
    final repo = HomeRepository(_SuccessApi());
    await repo.fetchHomeSummary('baby-1');
    await repo.fetchHomeSummary('baby-2');
    expect(repo.cachedHomeSummary('baby-1'), isNotNull);
    expect(repo.cachedHomeSummary('baby-2'), isNotNull);
  });
}

Map<String, dynamic> _babiesEnvelope(List<Map<String, dynamic>> items) => {
  'items': items,
  'offset': 0,
  'limit': 100,
  'has_more': false,
};

class _MixedBabiesApi extends ApiClient {
  _MixedBabiesApi() : super(idTokenProvider: () async => 'token');

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    return _babiesEnvelope([
      {
        'id': 'baby-o',
        'name': 'Owned',
        'role': 'owner',
        'lifecycle_status': 'expecting',
      },
      {
        'id': 'baby-f',
        'name': 'Followed',
        'role': 'follower',
        'lifecycle_status': 'expecting',
      },
    ]);
  }
}

class _FlakyBabiesApi extends ApiClient {
  _FlakyBabiesApi() : super(idTokenProvider: () async => 'token');

  var failRequests = false;

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    if (failRequests) {
      throw const SocketException('failed host lookup');
    }
    return _babiesEnvelope([
      {
        'id': 'baby-a',
        'name': 'Alpha',
        'role': 'owner',
        'lifecycle_status': 'expecting',
      },
      {
        'id': 'baby-b',
        'name': 'Beta',
        'role': 'owner',
        'lifecycle_status': 'expecting',
      },
    ]);
  }
}

class _GatedBabiesApi extends ApiClient {
  _GatedBabiesApi() : super(idTokenProvider: () async => 'token');

  final started = Completer<void>();
  final _gate = Completer<void>();

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    if (!started.isCompleted) started.complete();
    await _gate.future;
    return _babiesEnvelope([
      {
        'id': 'baby-a',
        'name': 'Alpha',
        'role': 'owner',
        'lifecycle_status': 'expecting',
      },
      {
        'id': 'baby-b',
        'name': 'Beta',
        'role': 'owner',
        'lifecycle_status': 'expecting',
      },
    ]);
  }
}

class _BabiesApi extends ApiClient {
  _BabiesApi() : super(idTokenProvider: () async => 'token');

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    expect(path, startsWith('/v1/babies'));
    return _babiesEnvelope([
      {
        'id': 'baby-a',
        'name': 'Alpha',
        'role': 'owner',
        'lifecycle_status': 'expecting',
      },
      {
        'id': 'baby-b',
        'name': 'Beta',
        'role': 'owner',
        'lifecycle_status': 'expecting',
      },
    ]);
  }
}

class _SuccessApi extends ApiClient {
  _SuccessApi() : super(idTokenProvider: () async => 'token');

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    expect(path, endsWith('/home-summary'));
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
}

class _FailingApi extends ApiClient {
  _FailingApi() : super(idTokenProvider: () async => 'token');

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    throw ApiException('Server error', statusCode: 500);
  }
}

class _FlakySummaryApi extends ApiClient {
  _FlakySummaryApi() : super(idTokenProvider: () async => 'token');

  var failRequests = false;

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    if (failRequests) {
      throw const SocketException('offline');
    }
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
}
