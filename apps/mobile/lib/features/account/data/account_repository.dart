import 'package:flutter/foundation.dart';
import 'package:lanonna/features/account/domain/data_export_status.dart';
import 'package:lanonna/features/invitations/domain/invitation_status.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/offset_page.dart';
import '../../../core/data/baby_list_cache.dart';
import '../../../core/data/single_flight.dart';
import '../../../core/domain/baby_summary.dart';
import '../../../core/json/json_readers.dart';

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
      photosSquished: readInt(json['photos_squished']),
      eventsAttended: readInt(json['events_attended']),
      itemsBought: readInt(json['items_bought']),
      comments: readInt(json['comments']),
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
      usedBytes: readInt(json['used_bytes']),
      quotaBytes: readInt(json['quota_bytes']),
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
    this.joinedAt,
  });

  final String firebaseUid;
  final String displayName;
  final String role;
  final bool canRemove;
  final String? joinedAt;

  factory MemberRow.fromJson(Map<String, dynamic> json) {
    return MemberRow(
      firebaseUid: json['firebase_uid'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      role: json['role'] as String? ?? 'follower',
      canRemove: json['can_remove'] as bool? ?? false,
      joinedAt: json['joined_at'] as String?,
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
  });

  final String id;
  final String email;
  final InvitationStatus status;
  final String? relationshipLabel;
  final InviteEmailDeliveryStatus? emailDeliveryStatus;

  bool get canResendEmail =>
      status == InvitationStatus.pending &&
      emailDeliveryStatus != InviteEmailDeliveryStatus.sent;

  factory InvitationRow.fromJson(Map<String, dynamic> json) {
    return InvitationRow(
      id: json['id']?.toString() ?? '',
      email: json['invitee_email'] as String? ?? '',
      status: InvitationStatus.fromApi(json['status'] as String?),
      relationshipLabel: json['relationship_label'] as String?,
      emailDeliveryStatus: InviteEmailDeliveryStatus.fromApi(
        json['email_delivery_status'] as String?,
      ),
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
  final DataExportStatus status;
  final String? downloadUrl;
  final String? errorMessage;

  factory DataExportJob.fromJson(Map<String, dynamic> json) => DataExportJob(
    id: json['id']?.toString() ?? '',
    status: DataExportStatus.fromApi(json['status'] as String?),
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
  AccountRepository(this._api, {BabyListCache? babyList})
    : _babyList = babyList;

  final ApiClient _api;
  final BabyListCache? _babyList;
  final AccountProfileUpdates profileUpdates = AccountProfileUpdates();
  final _accountLoad = SingleFlight<AccountPayload>();
  var _accountEpoch = 0;

  /// Last account payload from [fetchAccount] or a profile save.
  AccountPayload? get cachedAccount => profileUpdates.account;

  Future<AccountPayload> fetchAccount() async {
    final epoch = _accountEpoch;
    final json = await _api.getJson('/v1/me/account');
    final payload = AccountPayload.fromJson(json);
    // A response for the previous session must not repopulate the cache.
    if (epoch == _accountEpoch) profileUpdates.account = payload;
    return payload;
  }

  /// Loads the account once for passive readers (e.g. the shell top bar) and
  /// notifies [profileUpdates] listeners. No-op when already cached.
  ///
  /// Concurrent callers (shell, app lock, create baby) share one request.
  Future<void> ensureAccountLoaded() async {
    if (cachedAccount != null) return;
    final epoch = _accountEpoch;
    await _accountLoad.run(fetchAccount);
    if (epoch != _accountEpoch) return;
    profileUpdates.publish(profileUpdates.account);
  }

  /// Sign-out / account deletion: the next account starts with no profile.
  void clearCachedAccount() {
    _accountEpoch += 1;
    _accountLoad.cancel();
    profileUpdates.publish(null);
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
    final json = await _api.patchJson(
      '/v1/profile',
      body: {'biometric_unlock_enabled': enabled},
    );
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
    return _fetchOffsetList('/v1/babies/$babyId/members', MemberRow.fromJson);
  }

  Future<List<InvitationRow>> listInvitations(String babyId) async {
    return _fetchOffsetList(
      '/v1/babies/$babyId/invitations',
      InvitationRow.fromJson,
    );
  }

  Future<List<T>> _fetchOffsetList<T>(
    String path,
    T Function(Map<String, dynamic>) mapItem,
  ) {
    return fetchAllOffsetPages(
      (limit, offset) => _api.getJson('$path?limit=$limit&offset=$offset'),
      mapItem,
    );
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

  /// Removing a co-owner changes who else can leave (`can_leave`).
  Future<void> removeMember(String babyId, String firebaseUid) async {
    await _api.deleteJson('/v1/babies/$babyId/members/$firebaseUid');
    _babyList?.invalidate();
  }

  Future<void> leaveBaby(String babyId) async {
    await _api.postJson('/v1/babies/$babyId/leave', body: {});
    _babyList?.invalidate();
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

  Future<DeleteAccountPreview> fetchDeleteAccountPreview() async {
    final json = await _api.getJson('/v1/me/delete-account/preview');
    return DeleteAccountPreview.fromJson(json);
  }
}

class SoleOwnedBaby {
  const SoleOwnedBaby({required this.id, this.name});

  final String id;

  /// `null` for an unnamed baby (display via `babyNameLabel`).
  final String? name;
}

/// What deleting the account will do (`GET /v1/me/delete-account/preview`).
///
/// Deletion is never blocked (FR-SET-005); the preview lists the baby profiles
/// the caller owns alone, which are deleted with the account.
class DeleteAccountPreview {
  const DeleteAccountPreview({this.soleOwnedBabies = const []});

  final List<SoleOwnedBaby> soleOwnedBabies;

  factory DeleteAccountPreview.fromJson(Map<String, dynamic> json) {
    final babies = json['sole_owned_babies'];
    return DeleteAccountPreview(
      soleOwnedBabies: babies is List
          ? babies.whereType<Map<String, dynamic>>().map((row) {
              return SoleOwnedBaby(
                id: row['id']?.toString() ?? '',
                name: row['name'] as String?,
              );
            }).toList()
          : const [],
    );
  }
}
