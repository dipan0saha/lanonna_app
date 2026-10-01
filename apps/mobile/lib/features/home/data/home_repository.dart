import '../../../core/api/api_client.dart';
import '../../onboarding/data/models/baby_summary.dart';
import 'models/home_summary.dart';
import 'selected_baby_store.dart';

class HomeRepository {
  HomeRepository(this._api);

  final ApiClient _api;

  Future<List<BabySummary>> listBabies() async {
    final list = await _api.getJsonList('/v1/babies');
    return list
        .whereType<Map<String, dynamic>>()
        .map(BabySummary.fromJson)
        .toList();
  }

  /// Selected baby from [store], or first baby when none selected / id stale.
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async {
    final babies = await listBabies();
    if (babies.isEmpty) return null;
    final selectedId = store.selectedBabyId;
    final match = selectedId != null
        ? babies.where((b) => b.id == selectedId).firstOrNull
        : null;
    return match ?? babies.first;
  }

  Future<BabySummary> updateBaby(
    String babyId, {
    String? lifecycleStatus,
    String? actualBirthDate,
  }) async {
    final json = await _api.patchJson('/v1/babies/$babyId', body: {
      if (lifecycleStatus != null) 'lifecycle_status': lifecycleStatus,
      if (actualBirthDate != null) 'actual_birth_date': actualBirthDate,
    });
    return BabySummary.fromJson(json);
  }

  Future<BabySummary> updateBabyFields(
    String babyId, {
    String? name,
    String? gender,
    String? expectedBirthDate,
    String? actualBirthDate,
    String? lifecycleStatus,
  }) async {
    final json = await _api.patchJson('/v1/babies/$babyId', body: {
      if (name != null) 'name': name,
      if (gender != null) 'gender': gender,
      if (expectedBirthDate != null) 'expected_birth_date': expectedBirthDate,
      if (actualBirthDate != null) 'actual_birth_date': actualBirthDate,
      if (lifecycleStatus != null) 'lifecycle_status': lifecycleStatus,
    });
    return BabySummary.fromJson(json);
  }

  Future<BabySummary> createBaby({
    required String name,
    String? gender,
    String? expectedBirthDate,
    String? actualBirthDate,
    String lifecycleStatus = 'expecting',
  }) async {
    final json = await _api.postJson('/v1/babies', body: {
      'name': name,
      if (gender != null) 'gender': gender,
      if (expectedBirthDate != null) 'expected_birth_date': expectedBirthDate,
      if (actualBirthDate != null) 'actual_birth_date': actualBirthDate,
      'lifecycle_status': lifecycleStatus,
    });
    return BabySummary.fromJson(json);
  }

  Future<HomeSummary?> fetchHomeSummary(String babyId) async {
    try {
      final json = await _api.getJson('/v1/babies/$babyId/home-summary');
      return HomeSummary.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
