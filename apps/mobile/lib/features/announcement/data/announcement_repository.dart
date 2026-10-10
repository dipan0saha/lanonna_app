import '../../../core/api/api_client.dart';

class AnnouncementDetail {
  AnnouncementDetail({
    required this.id,
    this.firstName,
    this.lastName,
    this.gender,
    this.birthDate,
    this.birthTime,
    this.weightText,
    this.lengthText,
    this.photoDisplayUrl,
    required this.squishCount,
    required this.commentCount,
    required this.comments,
  });

  final String id;
  final String? firstName;
  final String? lastName;
  final String? gender;
  final String? birthDate;
  final String? birthTime;
  final String? weightText;
  final String? lengthText;
  final String? photoDisplayUrl;
  final int squishCount;
  final int commentCount;
  final List<Map<String, dynamic>> comments;

  factory AnnouncementDetail.fromJson(Map<String, dynamic> json) {
    final comments = json['comments'] as List<dynamic>? ?? [];
    return AnnouncementDetail(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      gender: json['gender'] as String?,
      birthDate: json['birth_date'] as String?,
      birthTime: json['birth_time'] as String?,
      weightText: json['weight_text'] as String?,
      lengthText: json['length_text'] as String?,
      photoDisplayUrl: json['photo_display_url'] as String?,
      squishCount: json['squish_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      comments: comments.whereType<Map<String, dynamic>>().toList(),
    );
  }
}

class AnnouncementRepository {
  AnnouncementRepository(this._api);

  final ApiClient _api;

  Future<AnnouncementDetail?> fetch(String babyId) async {
    try {
      final json = await _api.getJson('/v1/babies/$babyId/announcement');
      return AnnouncementDetail.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<AnnouncementDetail> save(
    String babyId, {
    required String firstName,
    String? lastName,
    String? gender,
    String? birthDate,
    String? birthTime,
    String? weightText,
    String? lengthText,
    String? photoId,
  }) async {
    final json = await _api.patchJson('/v1/babies/$babyId/announcement', body: {
      'first_name': firstName,
      'last_name': lastName,
      'gender': gender,
      'birth_date': birthDate,
      'birth_time': birthTime,
      'weight_text': weightText,
      'length_text': lengthText,
      if (photoId != null) 'photo_id': photoId,
    });
    return AnnouncementDetail.fromJson(json);
  }

  Future<void> squish(String babyId) async {
    await _api.postJson('/v1/babies/$babyId/announcement/squish');
  }

  Future<void> addComment(String babyId, String body) async {
    await _api.postJson('/v1/babies/$babyId/announcement/comments', body: {
      'body': body,
    });
  }
}
