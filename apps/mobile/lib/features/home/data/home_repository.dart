import '../../../core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/name_suggestion_draft.dart';
import '../../../core/api/offset_page.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/domain/baby_summary.dart';
import 'home_summary_result.dart';
import 'models/home_summary.dart';
import 'selected_baby_store.dart';

class HomeRepository {
  HomeRepository(this._api, {String? Function()? currentUserId})
    : _currentUserId = currentUserId;

  final ApiClient _api;
  final String? Function()? _currentUserId;
  List<BabySummary>? _cachedBabies;
  String? _cachedForUserId;
  var _listEpoch = 0;

  /// Last good summary per baby: offline fallback that survives baby switches.
  final Map<String, HomeSummary> _summaryByBaby = {};

  void clearCachedBabies() {
    _cachedBabies = null;
    _cachedForUserId = null;
    _listEpoch += 1;
    _summaryByBaby.clear();
  }

  HomeSummary? cachedHomeSummary(String babyId) => _summaryByBaby[babyId];

  /// Drop the cached baby list and select [babyId] (invite accept).
  ///
  /// A list fetched before the membership existed must not overwrite this
  /// selection or be served as the next offline snapshot.
  Future<void> rememberJoinedBaby(
    SelectedBabyStore store,
    String babyId,
  ) async {
    clearCachedBabies();
    await store.setSelectedBabyId(babyId);
  }

  Future<List<BabySummary>> _fetchAllBabies() {
    return fetchAllOffsetPages(
      (limit, offset) => _api.getJson('/v1/babies?limit=$limit&offset=$offset'),
      BabySummary.fromJson,
    );
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
    final epoch = _listEpoch;
    try {
      final babies = await _fetchAllBabies();
      if (epoch == _listEpoch) {
        _cachedBabies = babies;
        _cachedForUserId = uid;
      }
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
    final generation = store.selectionGeneration;
    final babies = await listBabies();
    if (store.selectionGeneration != generation) {
      final current = store.selectedBabyId;
      if (current == null) return null;
      return babies.where((b) => b.id == current).firstOrNull;
    }
    if (babies.isEmpty) return null;
    final selectedId = store.selectedBabyId;
    final match = selectedId != null
        ? babies.where((b) => b.id == selectedId).firstOrNull
        : null;
    final resolved = match ?? babies.first;
    await store.rememberResolvedBaby(resolved.id, resolved.name);
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

  /// `PATCH /v1/babies/{id}`: only the arguments given are sent. [name] is
  /// written whenever it is given, so `BabyNameWrite(null)` clears the name.
  Future<BabySummary> updateBaby(
    String babyId, {
    BabyNameWrite? name,
    BabyGender? gender,
    String? expectedBirthDate,
    String? actualBirthDate,
    BabyLifecycle? lifecycle,
    String? avatarUrl,
    List<NameSuggestionDraft> profileNameSuggestions = const [],
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name.value,
      if (gender != null) 'gender': gender.apiValue,
      if (expectedBirthDate != null) 'expected_birth_date': expectedBirthDate,
      if (actualBirthDate != null) 'actual_birth_date': actualBirthDate,
      if (lifecycle != null) 'lifecycle_status': lifecycle.apiValue,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (profileNameSuggestions.isNotEmpty)
        'profile_name_suggestions':
            profileNameSuggestions.map((r) => r.toJson()).toList(),
    };
    final json = await _api.patchJson('/v1/babies/$babyId', body: body);
    return BabySummary.fromJson(json);
  }

  Future<HomeSummaryResult> fetchHomeSummary(String babyId) async {
    try {
      final json = await _api.getJson('/v1/babies/$babyId/home-summary');
      final summary = HomeSummary.fromJson(json);
      _summaryByBaby[babyId] = summary;
      return HomeSummaryLoaded(summary);
    } on ApiException catch (e) {
      final cached = _summaryByBaby[babyId];
      if (cached != null && _shouldServeStaleBabyCache(e)) {
        return HomeSummaryLoaded(cached);
      }
      return HomeSummaryFailed(e);
    } catch (e) {
      final cached = _summaryByBaby[babyId];
      if (cached != null && _shouldServeStaleBabyCache(e)) {
        return HomeSummaryLoaded(cached);
      }
      return HomeSummaryFailed(e);
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
    final page = parseOffsetPage(
      json,
      HomeActivityItem.fromJson,
      defaultLimit: limit,
    );
    return ActivityPage(items: page.items, hasMore: page.hasMore);
  }
}

class ActivityPage {
  ActivityPage({required this.items, required this.hasMore});

  final List<HomeActivityItem> items;
  final bool hasMore;
}

/// The baby name to write in a profile update. `null` [value] clears the
/// name (the baby has none yet); omit the argument to leave it unchanged.
class BabyNameWrite {
  const BabyNameWrite(this.value);

  final String? value;
}
