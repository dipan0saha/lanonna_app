import '../../../core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'models/onboarding_status.dart';

class OnboardingRepository {
  OnboardingRepository(this._api);

  final ApiClient _api;

  Future<OnboardingStatus> fetchStatus() async {
    final json = await _api.getJson('/v1/onboarding/status');
    return OnboardingStatus.fromJson(json);
  }

  Future<void> completeOwnerOnboarding() async {
    await _api.postJson('/v1/onboarding/owner/complete');
  }

  Future<void> updateProfile({
    required String displayName,
    String? avatarUrl,
  }) async {
    await _api.patchJson('/v1/profile', body: {
      'display_name': displayName,
      if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
    });
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

  Future<void> sendBatchInvites(
    String babyId,
    List<Map<String, dynamic>> invites,
  ) async {
    await _api.postJson('/v1/babies/$babyId/invitations/batch', body: {
      'invites': invites,
    });
  }

  Future<void> seedFirstMoment(
    String babyId, {
    List<String> eventPresetIds = const [],
    List<String> registryPresetIds = const [],
    List<Map<String, String>> nameSuggestions = const [],
  }) async {
    await _api.postJson('/v1/babies/$babyId/onboarding/first-moment', body: {
      'event_preset_ids': eventPresetIds,
      'registry_preset_ids': registryPresetIds,
      'name_suggestions': nameSuggestions
          .map((r) => {'name': r['name'], 'gender': r['gender'] ?? 'unknown'})
          .toList(),
    });
  }
}
