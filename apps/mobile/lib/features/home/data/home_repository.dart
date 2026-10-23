import '../../../core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/name_suggestion_draft.dart';
import '../../../core/api/offset_page.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/domain/baby_summary.dart';
import '../../../core/data/baby_list_cache.dart';
import '../../../core/data/single_flight.dart';
import 'home_summary_result.dart';
import 'models/home_summary.dart';
import 'selected_baby_store.dart';

class HomeRepository {
  HomeRepository(
    ApiClient api, {
    String? Function()? currentUserId,
    BabyListCache? babyList,
    SelectedBabyStore? selectedBabyStore,
    DateTime Function()? clock,
  }) : _api = api,
       _babies =
           babyList ??
           BabyListCache(api, currentUserId: currentUserId, clock: clock),
       _selectedBabyStore = selectedBabyStore,
       _clock = clock ?? DateTime.now;

  final ApiClient _api;
  final BabyListCache _babies;
  final SelectedBabyStore? _selectedBabyStore;
  final DateTime Function() _clock;

  /// How long a home summary counts as current when the Home tab is shown
  /// again. Mutations elsewhere still refresh it at once
  /// ([HomeRefreshSignal.notifyHomeShouldRefresh]).
  static const summaryFreshFor = Duration(minutes: 1);

  /// Last good summary per baby: offline fallback that survives baby switches.
  final Map<String, HomeSummary> _summaryByBaby = {};
  final Map<String, DateTime> _summaryFetchedAt = {};

  /// Speculative summary reads (startup prefetch and Home's early load) share
  /// one request per baby. Non-speculative reads never join one: they follow
  /// mutations and must not get a response from before the change.
  final _speculativeSummary = KeyedSingleFlight<String, HomeSummaryResult>();

  /// Sign-out / account deletion: forget every user-scoped list.
  void clearCachedBabies() {
    _babies.invalidate();
    _speculativeSummary.cancelAll();
    _summaryByBaby.clear();
    _summaryFetchedAt.clear();
  }

  /// A membership or baby changed outside the repositories that already
  /// invalidate (e.g. the API reported `membership_ended`).
  void invalidateBabies() => _babies.invalidate();

  /// Pull-to-refresh: the next read refetches the baby list.
  void refreshBabiesOnNextRead() => _babies.markStale();

  HomeSummary? cachedHomeSummary(String babyId) => _summaryByBaby[babyId];

  /// Drop the cached baby list and select [babyId] (invite accept).
  ///
  /// A list fetched before the membership existed must not overwrite this
  /// selection or be served as the next offline snapshot.
  Future<void> rememberJoinedBaby(
    SelectedBabyStore store,
    String babyId,
  ) async {
    _babies.invalidate();
    await store.setSelectedBabyId(babyId);
  }

  static bool _shouldServeStaleSummary(Object error) {
    if (error is ApiException) {
      final code = error.statusCode;
      if (code != null && code >= 400 && code < 500) {
        return false;
      }
    }
    return true;
  }

  /// Every baby the user belongs to, from the shared [BabyListCache].
  Future<List<BabySummary>> listBabies() => _babies.read();

  /// [listBabies], but a list served from memory that does not contain
  /// [babyId] is refetched once (a baby joined on another device, a deep link
  /// or push for a newer membership), so a newer selection is never replaced
  /// by a stale list.
  Future<List<BabySummary>> _listBabiesContaining(String? babyId) async {
    final fromMemory = _babies.isFresh;
    final babies = await listBabies();
    if (babyId == null || !fromMemory || babies.any((b) => b.id == babyId)) {
      return babies;
    }
    _babies.markStale();
    return listBabies();
  }

  /// Selected baby from [store], or first baby when none selected / id stale.
  /// Persists the resolved id when the stored selection was missing or invalid.
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async {
    final generation = store.selectionGeneration;
    final babies = await _listBabiesContaining(store.selectedBabyId);
    if (store.selectionGeneration != generation) {
      final current = store.selectedBabyId;
      if (current == null) return null;
      return babies.where((b) => b.id == current).firstOrNull;
    }
    if (babies.isEmpty) {
      // No baby left (last one deleted or left): drop the remembered
      // selection so the shell title does not keep the old baby's name.
      await store.clearSelectedBabyId();
      return null;
    }
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
    final babies = await _listBabiesContaining(babyId);
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

  /// `PATCH /v1/babies/{id}`: only non-null arguments are sent. An empty
  /// [name] clears it (the baby becomes unnamed).
  Future<BabySummary> updateBaby(
    String babyId, {
    String? name,
    BabyGender? gender,
    String? expectedBirthDate,
    String? actualBirthDate,
    BabyLifecycle? lifecycle,
    String? avatarUrl,
    List<NameSuggestionDraft> profileNameSuggestions = const [],
  }) async {
    final body = <String, dynamic>{
      'name': ?name,
      if (gender != null) 'gender': gender.apiValue,
      'expected_birth_date': ?expectedBirthDate,
      'actual_birth_date': ?actualBirthDate,
      if (lifecycle != null) 'lifecycle_status': lifecycle.apiValue,
      'avatar_url': ?avatarUrl,
      if (profileNameSuggestions.isNotEmpty)
        'profile_name_suggestions':
            profileNameSuggestions.map((r) => r.toJson()).toList(),
    };
    final json = await _api.patchJson('/v1/babies/$babyId', body: body);
    _babies.invalidate();
    final updated = BabySummary.fromJson(json);
    final store = _selectedBabyStore;
    if (store != null && store.selectedBabyId == babyId) {
      await store.rememberResolvedBaby(babyId, updated.name);
    }
    return updated;
  }

  /// `GET home-summary`. With [maxAge], a summary fetched within that window
  /// is returned without a request (Home tab shown again); without it the
  /// summary is always refetched (mutations, pull-to-refresh, baby switch).
  ///
  /// [speculative]: requested for the stored selection before the baby list
  /// confirms it (Home loads both at once). A `membership_ended` answer then
  /// does not run the app-wide handler; Home discards a failed speculative
  /// result and requests again normally.
  Future<HomeSummaryResult> fetchHomeSummary(
    String babyId, {
    Duration? maxAge,
    bool speculative = false,
  }) async {
    final cachedAt = _summaryFetchedAt[babyId];
    final cachedSummary = _summaryByBaby[babyId];
    if (maxAge != null &&
        cachedSummary != null &&
        cachedAt != null &&
        _clock().difference(cachedAt) < maxAge) {
      return HomeSummaryLoaded(cachedSummary);
    }
    if (speculative) {
      return _speculativeSummary.run(
        babyId,
        () => _requestHomeSummary(babyId, speculative: true),
      );
    }
    return _requestHomeSummary(babyId, speculative: false);
  }

  Future<HomeSummaryResult> _requestHomeSummary(
    String babyId, {
    required bool speculative,
  }) async {
    try {
      final json = await _api.getJson(
        '/v1/babies/$babyId/home-summary',
        notifyMembershipEnded: !speculative,
      );
      final summary = HomeSummary.fromJson(json);
      _summaryByBaby[babyId] = summary;
      _summaryFetchedAt[babyId] = _clock();
      return HomeSummaryLoaded(summary);
    } catch (e) {
      final cached = _summaryByBaby[babyId];
      if (cached != null && _shouldServeStaleSummary(e)) {
        return HomeSummaryLoaded(cached, refreshError: e);
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
