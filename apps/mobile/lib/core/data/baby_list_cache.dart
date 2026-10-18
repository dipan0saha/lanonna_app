import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/offset_page.dart';
import 'single_flight.dart';
import '../domain/baby_summary.dart';

/// The signed-in user's baby memberships (`GET /v1/babies`), shared by every
/// screen through `HomeRepository`.
///
/// * A list fetched less than [freshFor] ago is served from memory.
/// * Concurrent reads share one request ([SingleFlight]).
/// * [markStale] (pull-to-refresh) refetches on the next read but keeps the
///   list as the offline fallback.
/// * [invalidate] (a membership or baby changed: create, edit, join, leave,
///   remove member, membership ended, sign-out) also drops the list and any
///   in-flight request, so a list from before the change is never served,
///   used as the offline fallback, or written back.
/// * The list belongs to the user who fetched it; another account never sees it.
class BabyListCache {
  BabyListCache(
    this._api, {
    String? Function()? currentUserId,
    this.freshFor = defaultFreshFor,
    DateTime Function()? clock,
  }) : _currentUserId = currentUserId,
       _clock = clock ?? DateTime.now;

  /// Short enough that another owner's edits or role changes show up on the
  /// next screen soon after; long enough that tab switches, baby switches and
  /// sub-screens never refetch the list.
  static const defaultFreshFor = Duration(minutes: 2);

  final ApiClient _api;
  final String? Function()? _currentUserId;
  final DateTime Function() _clock;
  final Duration freshFor;

  List<BabySummary>? _babies;
  String? _userId;
  DateTime? _fetchedAt;
  var _epoch = 0;
  final _request = SingleFlight<List<BabySummary>>();

  String? get _uid => _currentUserId?.call();

  /// Whether [read] would answer from memory without a request.
  bool get isFresh {
    final fetchedAt = _fetchedAt;
    return _babies != null &&
        _userId == _uid &&
        fetchedAt != null &&
        _clock().difference(fetchedAt) < freshFor;
  }

  /// The baby list: from memory while fresh, else from the network.
  Future<List<BabySummary>> read() {
    if (isFresh) return Future.value(_babies!);
    return _request.run(_fetch);
  }

  void markStale() => _fetchedAt = null;

  void invalidate() {
    _epoch += 1;
    _babies = null;
    _userId = null;
    _fetchedAt = null;
    _request.cancel();
  }

  Future<List<BabySummary>> _fetch() async {
    final epoch = _epoch;
    final uid = _uid;
    try {
      final babies = await fetchAllOffsetPages(
        (limit, offset) =>
            _api.getJson('/v1/babies?limit=$limit&offset=$offset'),
        BabySummary.fromJson,
      );
      if (epoch == _epoch && uid == _uid) {
        _babies = babies;
        _userId = uid;
        _fetchedAt = _clock();
      }
      return babies;
    } catch (e) {
      final cached = _babies;
      if (epoch == _epoch &&
          cached != null &&
          cached.isNotEmpty &&
          uid != null &&
          uid == _userId &&
          _shouldServeStale(e)) {
        return cached;
      }
      rethrow;
    }
  }

  /// A 4xx means the request itself was refused (signed out, removed); only
  /// network and server failures fall back to the last list.
  static bool _shouldServeStale(Object error) {
    if (error is ApiException) {
      final code = error.statusCode;
      if (code != null && code >= 400 && code < 500) return false;
    }
    return true;
  }
}
