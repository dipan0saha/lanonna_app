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
    expect(loaded.summary.lifecycleStatus, 'expecting');
    expect(loaded.summary.teasers?.registryOpenCount, 1);
    expect(loaded.summary.recentActivity, isEmpty);
  });

  test('resolveSelectedBaby uses first baby when none selected', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    final repo = HomeRepository(_BabiesApi());
    final baby = await repo.resolveSelectedBaby(store);
    expect(baby?.id, 'baby-a');
    expect(baby?.name, 'Alpha');
    expect(store.selectedBabyId, 'baby-a');
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
}

class _MixedBabiesApi extends ApiClient {
  _MixedBabiesApi() : super(idTokenProvider: () async => 'token');

  @override
  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    return [
      {'id': 'baby-o', 'name': 'Owned', 'role': 'owner', 'lifecycle_status': 'expecting'},
      {'id': 'baby-f', 'name': 'Followed', 'role': 'follower', 'lifecycle_status': 'expecting'},
    ];
  }
}

class _BabiesApi extends ApiClient {
  _BabiesApi() : super(idTokenProvider: () async => 'token');

  @override
  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    expect(path, '/v1/babies');
    return [
      {'id': 'baby-a', 'name': 'Alpha', 'role': 'owner', 'lifecycle_status': 'expecting'},
      {'id': 'baby-b', 'name': 'Beta', 'role': 'owner', 'lifecycle_status': 'expecting'},
    ];
  }
}

class _SuccessApi extends ApiClient {
  _SuccessApi() : super(idTokenProvider: () async => 'token');

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    expect(path, '/v1/babies/baby-1/home-summary');
    return {
      'lifecycle_status': 'expecting',
      'family_insight': {
        'name_suggestion_count': 0,
        'vote_count': 0,
        'gender_totals': {'male': 0, 'female': 0},
      },
      'teasers': {
        'registry_open_count': 1,
        'registry_highlights': [],
        'recent_photos': [],
        'favorite_photos': [],
        'recent_registry_purchases': [],
        'upcoming_events': [],
        'rsvp_reminders': [],
        'notification_preview': [],
      },
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
