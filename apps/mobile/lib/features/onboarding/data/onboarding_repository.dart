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
    String? phone,
    String? birthDate,
    String? countryCode,
    String? postalCode,
    bool acceptTerms = false,
  }) async {
    await _api.patchJson('/v1/profile', body: {
      'display_name': displayName,
      if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (birthDate != null && birthDate.isNotEmpty) 'birth_date': birthDate,
      if (countryCode != null && countryCode.isNotEmpty) 'country_code': countryCode,
      if (postalCode != null && postalCode.isNotEmpty) 'postal_code': postalCode,
      'accept_terms': acceptTerms,
    });
  }

  Future<BabySummary> createBaby({
    required String name,
    String? gender,
    String? expectedBirthDate,
    String? actualBirthDate,
    String lifecycleStatus = 'expecting',
    String? relationshipLabel,
    List<Map<String, String>> profileNameSuggestions = const [],
  }) async {
    final json = await _api.postJson('/v1/babies', body: {
      'name': name,
      if (gender != null) 'gender': gender,
      if (expectedBirthDate != null) 'expected_birth_date': expectedBirthDate,
      if (actualBirthDate != null) 'actual_birth_date': actualBirthDate,
      'lifecycle_status': lifecycleStatus,
      if (relationshipLabel != null && relationshipLabel.isNotEmpty)
        'relationship_label': relationshipLabel,
      if (profileNameSuggestions.isNotEmpty)
        'profile_name_suggestions': profileNameSuggestions
            .map((r) => {'name': r['name'], 'gender': r['gender'] ?? 'unknown'})
            .toList(),
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
