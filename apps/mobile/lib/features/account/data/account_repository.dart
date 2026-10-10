import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/domain/baby_summary.dart';

class UserEngagementStats {
  const UserEngagementStats({
    required this.photosSquished,
    required this.eventsAttended,
    required this.itemsBought,
    required this.comments,
  });

  final int photosSquished;
  final int eventsAttended;
  final int itemsBought;
  final int comments;

  factory UserEngagementStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const UserEngagementStats(
        photosSquished: 0,
        eventsAttended: 0,
        itemsBought: 0,
        comments: 0,
      );
    }
    return UserEngagementStats(
      photosSquished: json['photos_squished'] as int? ?? 0,
      eventsAttended: json['events_attended'] as int? ?? 0,
      itemsBought: json['items_bought'] as int? ?? 0,
      comments: json['comments'] as int? ?? 0,
    );
  }
}

class StorageUsage {
  const StorageUsage({required this.usedBytes, required this.quotaBytes});

  final int usedBytes;
  final int quotaBytes;

  factory StorageUsage.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const StorageUsage(usedBytes: 0, quotaBytes: 0);
    return StorageUsage(
      usedBytes: json['used_bytes'] as int? ?? 0,
      quotaBytes: json['quota_bytes'] as int? ?? 0,
    );
  }

  double get usedFraction =>
      quotaBytes > 0 ? (usedBytes / quotaBytes).clamp(0.0, 1.0) : 0;
}

class AccountPayload {
  AccountPayload({
    required this.displayName,
    required this.email,
    required this.babies,
    required this.engagement,
    this.storageUsage,
    this.avatarUrl,
    this.phone,
    this.birthDate,
    this.countryCode,
    this.postalCode,
  });

  final String? displayName;
  final String? email;
  final String? avatarUrl;
  final String? phone;
  final String? birthDate;
  final String? countryCode;
  final String? postalCode;
  final List<BabySummary> babies;
  final UserEngagementStats engagement;
  final StorageUsage? storageUsage;

  bool get hasOwnerBaby => babies.any((b) => b.role == 'owner');

  factory AccountPayload.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? {};
    final babies = json['babies'] as List<dynamic>? ?? [];
    final storageRaw = json['storage_usage'] as Map<String, dynamic>?;
    return AccountPayload(
      displayName: profile['display_name'] as String?,
      email: profile['email'] as String?,
      avatarUrl: profile['avatar_url'] as String?,
      phone: profile['phone'] as String?,
      birthDate: profile['birth_date'] as String?,
      countryCode: profile['country_code'] as String?,
      postalCode: profile['postal_code'] as String?,
      babies: babies
          .whereType<Map<String, dynamic>>()
          .map(BabySummary.fromJson)
          .toList(),
      engagement: UserEngagementStats.fromJson(
        json['engagement'] as Map<String, dynamic>?,
      ),
      storageUsage: storageRaw != null ? StorageUsage.fromJson(storageRaw) : null,
    );
  }
}

class MemberRow {
  MemberRow({
    required this.firebaseUid,
    required this.displayName,
    required this.role,
    required this.canRemove,
    this.email,
    this.relationshipLabel,
  });

  final String firebaseUid;
  final String displayName;
  final String role;
  final bool canRemove;
  final String? email;
  final String? relationshipLabel;

  factory MemberRow.fromJson(Map<String, dynamic> json) {
    return MemberRow(
      firebaseUid: json['firebase_uid'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Member',
      role: json['role'] as String? ?? 'follower',
      canRemove: json['can_remove'] as bool? ?? false,
      email: json['email'] as String?,
      relationshipLabel: json['relationship_label'] as String?,
    );
  }
}

class InvitationRow {
  InvitationRow({
    required this.id,
    required this.email,
    required this.status,
    this.relationshipLabel,
  });

  final String id;
  final String email;
  final String status;
  final String? relationshipLabel;

  factory InvitationRow.fromJson(Map<String, dynamic> json) {
    return InvitationRow(
      id: json['id']?.toString() ?? '',
      email: json['invitee_email'] as String? ?? '',
      status: json['status'] as String? ?? '',
      relationshipLabel: json['relationship_label'] as String?,
    );
  }
}

class DataExportJob {
  DataExportJob({
    required this.id,
    required this.status,
    this.downloadUrl,
    this.errorMessage,
  });

  final String id;
  final String status;
  final String? downloadUrl;
  final String? errorMessage;

  factory DataExportJob.fromJson(Map<String, dynamic> json) => DataExportJob(
        id: json['id']?.toString() ?? '',
        status: json['status'] as String? ?? 'pending',
        downloadUrl: json['download_url'] as String?,
        errorMessage: json['error_message'] as String?,
      );
}

class AccountRepository {
  AccountRepository(this._api);

  final ApiClient _api;

  Future<AccountPayload> fetchAccount() async {
    final json = await _api.getJson('/v1/me/account');
    return AccountPayload.fromJson(json);
  }

  Future<void> updateProfile({
    required String displayName,
    String? avatarUrl,
    String? phone,
    String? birthDate,
    String? countryCode,
    String? postalCode,
  }) async {
    await _api.patchJson('/v1/profile', body: {
      'display_name': displayName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (birthDate != null && birthDate.isNotEmpty) 'birth_date': birthDate,
      if (countryCode != null && countryCode.isNotEmpty) 'country_code': countryCode,
      if (postalCode != null && postalCode.isNotEmpty) 'postal_code': postalCode,
    });
  }

  Future<List<MemberRow>> listMembers(String babyId) async {
    final list = await _api.getJsonList('/v1/babies/$babyId/members');
    return list.whereType<Map<String, dynamic>>().map(MemberRow.fromJson).toList();
  }

  Future<List<InvitationRow>> listInvitations(String babyId) async {
    final list = await _api.getJsonList('/v1/babies/$babyId/invitations');
    return list
        .whereType<Map<String, dynamic>>()
        .map(InvitationRow.fromJson)
        .toList();
  }

  Future<void> revokeInvitation(String babyId, String invitationId) async {
    await _api.deleteJson('/v1/babies/$babyId/invitations/$invitationId');
  }

  Future<void> removeMember(String babyId, String firebaseUid) async {
    await _api.deleteJson('/v1/babies/$babyId/members/$firebaseUid');
  }

  Future<void> leaveBaby(String babyId) async {
    await _api.postJson('/v1/babies/$babyId/leave', body: {});
  }

  Future<DataExportJob> requestExport(String babyId) async {
    final json = await _api.postJson('/v1/babies/$babyId/data-export', body: {});
    return DataExportJob.fromJson(json);
  }

  Future<DataExportJob?> fetchLatestExport(String babyId) async {
    try {
      final json = await _api.getJson('/v1/babies/$babyId/data-export/latest');
      return DataExportJob.fromJson(json);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    await _api.postJson('/v1/me/delete-account', body: {'confirm': true});
  }

  Future<DeleteAccountEligibility> fetchDeleteAccountEligibility() async {
    final json = await _api.getJson('/v1/me/delete-account/eligibility');
    return DeleteAccountEligibility.fromJson(json);
  }
}

class DeleteAccountEligibility {
  const DeleteAccountEligibility({
    required this.allowed,
    required this.blockers,
  });

  final bool allowed;
  final List<String> blockers;

  factory DeleteAccountEligibility.fromJson(Map<String, dynamic> json) {
    final raw = json['blockers'];
    return DeleteAccountEligibility(
      allowed: json['allowed'] as bool? ?? false,
      blockers: raw is List
          ? raw.map((e) => e.toString()).toList()
          : const [],
    );
  }
}
