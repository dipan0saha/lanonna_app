import '../../../core/api/api_client.dart';
import 'models/fun_models.dart';

class FunRepository {
  FunRepository(this._api);

  final ApiClient _api;

  Future<NamesPayload> fetchNames(String babyId) async {
    final json = await _api.getJson('/v1/babies/$babyId/fun/names');
    return NamesPayload.fromJson(json);
  }

  Future<void> suggestName(String babyId, String name, String gender) async {
    await _api.postJson('/v1/babies/$babyId/fun/names', body: {
      'suggested_name': name,
      'gender': gender,
    });
  }

  Future<void> deleteSuggestion(String babyId, String suggestionId) async {
    await _api.deleteJson('/v1/babies/$babyId/fun/names/$suggestionId');
  }

  Future<bool> toggleLike(String babyId, String suggestionId) async {
    final json =
        await _api.postJson('/v1/babies/$babyId/fun/names/$suggestionId/like');
    return json['liked'] as bool? ?? false;
  }

  Future<PredictionsPayload> fetchPredictions(String babyId) async {
    final json = await _api.getJson('/v1/babies/$babyId/fun/predictions');
    return PredictionsPayload.fromJson(json);
  }

  Future<void> setGenderVote(String babyId, String gender) async {
    await _api.putJson('/v1/babies/$babyId/fun/predictions/gender', body: {
      'gender': gender,
    });
  }

  Future<void> setBirthdateVote(String babyId, DateTime date) async {
    final iso =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await _api.putJson('/v1/babies/$babyId/fun/predictions/birthdate', body: {
      'predicted_birth_date': iso,
    });
  }
}
