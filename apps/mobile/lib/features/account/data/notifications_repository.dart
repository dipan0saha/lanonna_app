import '../../../core/api/api_client.dart';

class NotificationPreferences {
  NotificationPreferences({
    required this.digest,
    required this.pushEnabled,
    required this.emailDigestEnabled,
    required this.notifyGalleryEnabled,
    required this.notifyCalendarEnabled,
    required this.notifyRegistryEnabled,
    required this.notifyCommentsEnabled,
  });

  final String digest;
  final bool pushEnabled;
  final bool emailDigestEnabled;
  final bool notifyGalleryEnabled;
  final bool notifyCalendarEnabled;
  final bool notifyRegistryEnabled;
  final bool notifyCommentsEnabled;

  NotificationPreferences copyWith({
    String? digest,
    bool? pushEnabled,
    bool? emailDigestEnabled,
    bool? notifyGalleryEnabled,
    bool? notifyCalendarEnabled,
    bool? notifyRegistryEnabled,
    bool? notifyCommentsEnabled,
  }) {
    return NotificationPreferences(
      digest: digest ?? this.digest,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailDigestEnabled: emailDigestEnabled ?? this.emailDigestEnabled,
      notifyGalleryEnabled: notifyGalleryEnabled ?? this.notifyGalleryEnabled,
      notifyCalendarEnabled:
          notifyCalendarEnabled ?? this.notifyCalendarEnabled,
      notifyRegistryEnabled:
          notifyRegistryEnabled ?? this.notifyRegistryEnabled,
      notifyCommentsEnabled:
          notifyCommentsEnabled ?? this.notifyCommentsEnabled,
    );
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      digest: json['notification_digest'] as String? ?? 'realtime',
      pushEnabled: json['push_notifications_enabled'] as bool? ?? true,
      emailDigestEnabled: json['email_digest_enabled'] as bool? ?? true,
      notifyGalleryEnabled: json['notify_gallery_enabled'] as bool? ?? true,
      notifyCalendarEnabled: json['notify_calendar_enabled'] as bool? ?? true,
      notifyRegistryEnabled: json['notify_registry_enabled'] as bool? ?? true,
      notifyCommentsEnabled: json['notify_comments_enabled'] as bool? ?? true,
    );
  }
}

class InboxNotification {
  InboxNotification({
    required this.id,
    required this.title,
    required this.body,
    this.readAt,
    this.deepLink,
    this.babyProfileId,
  });

  final String id;
  final String title;
  final String body;
  final String? readAt;
  final String? deepLink;
  final String? babyProfileId;

  factory InboxNotification.fromJson(Map<String, dynamic> json) {
    return InboxNotification(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      readAt: json['read_at'] as String?,
      deepLink: json['deep_link'] as String?,
      babyProfileId: json['baby_profile_id']?.toString(),
    );
  }
}

class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  Future<NotificationPreferences> fetchPreferences() async {
    final json = await _api.getJson('/v1/me/notification-preferences');
    return NotificationPreferences.fromJson(json);
  }

  Future<NotificationPreferences> updatePreferences({
    String? digest,
    bool? pushEnabled,
    bool? emailDigestEnabled,
    bool? notifyGalleryEnabled,
    bool? notifyCalendarEnabled,
    bool? notifyRegistryEnabled,
    bool? notifyCommentsEnabled,
  }) async {
    final body = <String, dynamic>{};
    if (digest != null) body['notification_digest'] = digest;
    if (pushEnabled != null) body['push_notifications_enabled'] = pushEnabled;
    if (emailDigestEnabled != null) {
      body['email_digest_enabled'] = emailDigestEnabled;
    }
    if (notifyGalleryEnabled != null) {
      body['notify_gallery_enabled'] = notifyGalleryEnabled;
    }
    if (notifyCalendarEnabled != null) {
      body['notify_calendar_enabled'] = notifyCalendarEnabled;
    }
    if (notifyRegistryEnabled != null) {
      body['notify_registry_enabled'] = notifyRegistryEnabled;
    }
    if (notifyCommentsEnabled != null) {
      body['notify_comments_enabled'] = notifyCommentsEnabled;
    }
    final json = await _api.patchJson('/v1/me/notification-preferences', body: body);
    return NotificationPreferences.fromJson(json);
  }

  Future<List<InboxNotification>> listInbox() async {
    final list = await _api.getJsonList('/v1/me/notifications');
    return list
        .whereType<Map<String, dynamic>>()
        .map(InboxNotification.fromJson)
        .toList();
  }

  Future<void> markRead(String id) async {
    await _api.patchJson('/v1/me/notifications/$id/read', body: {});
  }

  Future<int> unreadCount() async {
    final json = await _api.getJson('/v1/me/notifications/unread-count');
    return json['count'] as int? ?? 0;
  }

  Future<void> registerDeviceToken({
    required String fcmToken,
    required String platform,
  }) async {
    await _api.putJson('/v1/me/device-tokens', body: {
      'fcm_token': fcmToken,
      'platform': platform,
    });
  }

  Future<void> unregisterDeviceToken(String fcmToken) async {
    await _api.deleteJson('/v1/me/device-tokens', body: {
      'fcm_token': fcmToken,
    });
  }
}
