import '../../../core/api/api_client.dart';
import '../../../core/api/api_error_message.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/domain/baby_summary.dart';
import 'home_summary_result.dart';
import 'models/home_summary.dart';
import 'selected_baby_store.dart';

class HomeRepository {
  HomeRepository(
    this._api, {
    String? Function()? currentUserId,
  }) : _currentUserId = currentUserId;

  final ApiClient _api;
  final String? Function()? _currentUserId;
  List<BabySummary>? _cachedBabies;
  String? _cachedForUserId;

  void clearCachedBabies() {
    _cachedBabies = null;
    _cachedForUserId = null;
  }

  static bool _shouldServeStaleBabyCache(Object error) {
    if (error is ApiException) {
      final code = error.statusCode;
      if (code != null && code >= 400 && code < 500) {
        return false;
      }
    }
    return true;
  }

  Future<List<BabySummary>> listBabies() async {
    final uid = _currentUserId?.call();
    if (uid != _cachedForUserId) {
      _cachedBabies = null;
    }
    try {
      final list = await _api.getJsonList('/v1/babies');
      final babies = list
          .whereType<Map<String, dynamic>>()
          .map(BabySummary.fromJson)
          .toList();
      _cachedBabies = babies;
      _cachedForUserId = uid;
      return babies;
    } catch (e) {
      final cached = _cachedBabies;
      if (cached != null &&
          cached.isNotEmpty &&
          uid != null &&
          uid == _cachedForUserId &&
          _shouldServeStaleBabyCache(e)) {
        return cached;
      }
      rethrow;
    }
  }

  /// Selected baby from [store], or first baby when none selected / id stale.
  /// Persists the resolved id when the stored selection was missing or invalid.
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async {
    final babies = await listBabies();
    if (babies.isEmpty) return null;
    final selectedId = store.selectedBabyId;
    final match = selectedId != null
        ? babies.where((b) => b.id == selectedId).firstOrNull
        : null;
    final resolved = match ?? babies.first;
    if (selectedId != resolved.id) {
      await store.setSelectedBabyId(resolved.id);
    }
    return resolved;
  }

  /// Baby membership for a specific profile id (route/deep-link scoped loads).
  Future<BabySummary?> babyById(String babyId) async {
    final babies = await listBabies();
    return babies.where((b) => b.id == babyId).firstOrNull;
  }

  /// Owner baby for owner-only flows: selected baby when owner, else first owned baby.
  Future<BabySummary?> resolveOwnerBaby(SelectedBabyStore store) async {
    final babies = await listBabies();
    final owners = babies.where((b) => b.role == 'owner').toList();
    if (owners.isEmpty) return null;
    final selectedId = store.selectedBabyId;
    final selectedOwner = selectedId != null
        ? owners.where((b) => b.id == selectedId).firstOrNull
        : null;
    return selectedOwner ?? owners.first;
  }

  Future<BabySummary> updateBaby(
    String babyId, {
    String? name,
    String? gender,
    String? expectedBirthDate,
    String? actualBirthDate,
    String? lifecycleStatus,
    String? avatarUrl,
  }) async {
    final json = await _api.patchJson('/v1/babies/$babyId', body: {
      ?'name': name,
      ?'gender': gender,
      ?'expected_birth_date': expectedBirthDate,
      ?'actual_birth_date': actualBirthDate,
      ?'lifecycle_status': lifecycleStatus,
      ?'avatar_url': avatarUrl,
    });
    return BabySummary.fromJson(json);
  }

  Future<HomeSummaryResult> fetchHomeSummary(String babyId) async {
    try {
      final json = await _api.getJson('/v1/babies/$babyId/home-summary');
      return HomeSummaryLoaded(HomeSummary.fromJson(json));
    } on ApiException catch (e) {
      return HomeSummaryFailed(e);
    } catch (e) {
      return HomeSummaryFailed(
        ApiException(apiErrorMessage(e)),
      );
    }
  }

  Future<void> dismissSystemAnnouncement(String announcementId) async {
    await _api.postJson(
      '/v1/me/system-announcements/$announcementId/dismiss',
      body: {},
    );
  }

  Future<ActivityPage> fetchActivityPage(
    String babyId, {
    int limit = 20,
    int offset = 0,
    String scope = 'all',
  }) async {
    final json = await _api.getJson(
      '/v1/babies/$babyId/activity-events?limit=$limit&offset=$offset&scope=$scope',
    );
    final items = (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(HomeActivityItem.fromJson)
        .toList();
    return ActivityPage(
      items: items,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}

class ActivityPage {
  ActivityPage({required this.items, required this.hasMore});

  final List<HomeActivityItem> items;
  final bool hasMore;
}
