import 'package:flutter/foundation.dart';

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
    this.biometricUnlockEnabled = false,
  });

  final String? displayName;
  final String? email;
  final String? avatarUrl;
  final String? phone;
  final String? birthDate;
  final String? countryCode;
  final String? postalCode;
  final bool biometricUnlockEnabled;
  final List<BabySummary> babies;
  final UserEngagementStats engagement;
  final StorageUsage? storageUsage;

  bool get hasOwnerBaby => babies.any((b) => b.role == 'owner');

  AccountPayload copyWithProfile({
    String? displayName,
    String? email,
    String? avatarUrl,
    String? phone,
    String? birthDate,
    String? countryCode,
    String? postalCode,
    bool? biometricUnlockEnabled,
  }) {
    return AccountPayload(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      babies: babies,
      engagement: engagement,
      storageUsage: storageUsage,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone,
      birthDate: birthDate,
      countryCode: countryCode,
      postalCode: postalCode,
      biometricUnlockEnabled:
          biometricUnlockEnabled ?? this.biometricUnlockEnabled,
    );
  }

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
      biometricUnlockEnabled:
          profile['biometric_unlock_enabled'] as bool? ?? false,
      babies: babies
          .whereType<Map<String, dynamic>>()
          .map(BabySummary.fromJson)
          .toList(),
      engagement: UserEngagementStats.fromJson(
        json['engagement'] as Map<String, dynamic>?,
      ),
      storageUsage: storageRaw != null
          ? StorageUsage.fromJson(storageRaw)
          : null,
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
    this.emailDeliveryStatus,
    this.emailLastError,
  });

  final String id;
  final String email;
  final String status;
  final String? relationshipLabel;
  final String? emailDeliveryStatus;
  final String? emailLastError;

  bool get canResendEmail =>
      status == 'pending' && emailDeliveryStatus != 'sent';

  factory InvitationRow.fromJson(Map<String, dynamic> json) {
    return InvitationRow(
      id: json['id']?.toString() ?? '',
      email: json['invitee_email'] as String? ?? '',
      status: json['status'] as String? ?? '',
      relationshipLabel: json['relationship_label'] as String?,
      emailDeliveryStatus: json['email_delivery_status'] as String?,
      emailLastError: json['email_last_error'] as String?,
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

/// Latest account payload. Profile saves notify listeners; fetches only store it.
class AccountProfileUpdates extends ChangeNotifier {
  AccountPayload? account;

  void publish(AccountPayload? value) {
    account = value;
    notifyListeners();
  }
}

class AccountRepository {
  AccountRepository(this._api);

  final ApiClient _api;
  final AccountProfileUpdates profileUpdates = AccountProfileUpdates();

  /// Last account payload from [fetchAccount] or a profile save.
  AccountPayload? get cachedAccount => profileUpdates.account;

  Future<AccountPayload> fetchAccount() async {
    final json = await _api.getJson('/v1/me/account');
    final payload = AccountPayload.fromJson(json);
    profileUpdates.account = payload;
    return payload;
  }

  Future<void> updateProfile({
    required String displayName,
    String? avatarUrl,
    String? phone,
    String? birthDate,
    String? countryCode,
    String? postalCode,
    bool sendExplicitNulls = false,
  }) async {
    final Map<String, dynamic> body;
    if (sendExplicitNulls) {
      body = {
        'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'phone': phone != null && phone.trim().isEmpty ? null : phone?.trim(),
        'birth_date': birthDate != null && birthDate.trim().isEmpty
            ? null
            : birthDate?.trim(),
        'country_code': countryCode != null && countryCode.trim().isEmpty
            ? null
            : countryCode?.trim(),
        'postal_code': postalCode != null && postalCode.trim().isEmpty
            ? null
            : postalCode?.trim(),
      };
    } else {
      body = {
        'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (birthDate != null && birthDate.isNotEmpty) 'birth_date': birthDate,
        if (countryCode != null && countryCode.isNotEmpty)
          'country_code': countryCode,
        if (postalCode != null && postalCode.isNotEmpty)
          'postal_code': postalCode,
      };
    }
    final json = await _api.patchJson('/v1/profile', body: body);
    _rememberProfileResponse(json, fallbackDisplayName: displayName);
  }

  Future<void> setBiometricUnlockEnabled(bool enabled) async {
    final json = await _api.patchJson('/v1/profile', body: {
      'biometric_unlock_enabled': enabled,
    });
    _rememberProfileResponse(
      json,
      fallbackDisplayName: profileUpdates.account?.displayName ?? '',
    );
  }

  void _rememberProfileResponse(
    Map<String, dynamic> json, {
    required String fallbackDisplayName,
  }) {
    final current = profileUpdates.account;
    if (current == null) {
      profileUpdates.publish(null);
      return;
    }
    profileUpdates.publish(
      current.copyWithProfile(
        displayName: json['display_name'] as String? ?? fallbackDisplayName,
        email: json['email'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        phone: json['phone'] as String?,
        birthDate: json['birth_date'] as String?,
        countryCode: json['country_code'] as String?,
        postalCode: json['postal_code'] as String?,
        biometricUnlockEnabled:
            json['biometric_unlock_enabled'] as bool? ??
            current.biometricUnlockEnabled,
      ),
    );
  }

  Future<List<MemberRow>> listMembers(String babyId) async {
    final list = await _api.getJsonList('/v1/babies/$babyId/members');
    return list
        .whereType<Map<String, dynamic>>()
        .map(MemberRow.fromJson)
        .toList();
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

  Future<void> resendInvitation(String babyId, String invitationId) async {
    await _api.postJson(
      '/v1/babies/$babyId/invitations/$invitationId/resend',
      body: {},
    );
  }

  Future<void> removeMember(String babyId, String firebaseUid) async {
    await _api.deleteJson('/v1/babies/$babyId/members/$firebaseUid');
  }

  Future<void> leaveBaby(String babyId) async {
    await _api.postJson('/v1/babies/$babyId/leave', body: {});
  }

  Future<DataExportJob> requestExport(String babyId) async {
    final json = await _api.postJson(
      '/v1/babies/$babyId/data-export',
      body: {},
    );
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

class SoleOwnedBaby {
  const SoleOwnedBaby({required this.id, required this.name});

  final String id;
  final String name;
}

class DeleteAccountEligibility {
  const DeleteAccountEligibility({
    required this.allowed,
    required this.blockers,
    this.soleOwnedBabies = const [],
  });

  final bool allowed;
  final List<String> blockers;
  final List<SoleOwnedBaby> soleOwnedBabies;

  factory DeleteAccountEligibility.fromJson(Map<String, dynamic> json) {
    final raw = json['blockers'];
    final babies = json['sole_owned_babies'];
    return DeleteAccountEligibility(
      allowed: json['allowed'] as bool? ?? false,
      blockers: raw is List ? raw.map((e) => e.toString()).toList() : const [],
      soleOwnedBabies: babies is List
          ? babies.whereType<Map<String, dynamic>>().map((row) {
              return SoleOwnedBaby(
                id: row['id']?.toString() ?? '',
                name: row['name']?.toString() ?? '',
              );
            }).toList()
          : const [],
    );
  }
}
