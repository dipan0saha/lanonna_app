import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lanonna/features/account/domain/notification_digest.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/offset_page.dart';
import '../../../core/data/single_flight.dart';
import '../../../core/time/app_date_time.dart';
import '../../../core/json/json_readers.dart';
import '../../../core/domain/feed_params.dart';
import '../domain/inbox_notification_kind.dart';
import '../domain/inbox_notification_type.dart';

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

  final NotificationDigest digest;
  final bool pushEnabled;
  final bool emailDigestEnabled;
  final bool notifyGalleryEnabled;
  final bool notifyCalendarEnabled;
  final bool notifyRegistryEnabled;
  final bool notifyCommentsEnabled;

  NotificationPreferences copyWith({
    NotificationDigest? digest,
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
      digest: NotificationDigest.fromApi(json['notification_digest'] as String?),
      pushEnabled: json['push_notifications_enabled'] as bool? ?? true,
      emailDigestEnabled: json['email_digest_enabled'] as bool? ?? true,
      notifyGalleryEnabled: json['notify_gallery_enabled'] as bool? ?? true,
      notifyCalendarEnabled: json['notify_calendar_enabled'] as bool? ?? true,
      notifyRegistryEnabled: json['notify_registry_enabled'] as bool? ?? true,
      notifyCommentsEnabled: json['notify_comments_enabled'] as bool? ?? true,
    );
  }
}

/// One inbox row (`GET /v1/me/notifications`).
///
/// [kind] + [params] + [actorDisplayName] are rendered from ARB by
/// `inboxSentence`. [title] / [body] are the English push copy the worker sent;
/// they are shown only for a row with no (or an unknown) kind.
class InboxNotification {
  InboxNotification({
    required this.id,
    this.title = '',
    this.body = '',
    this.kind,
    this.params = const {},
    this.readAt,
    this.deepLink,
    this.babyProfileId,
    this.createdAt,
    this.notificationType = InboxNotificationType.generic,
    this.actorDisplayName,
  });

  final String id;
  final String title;
  final String body;
  final InboxNotificationKind? kind;
  final Map<String, String> params;
  final String? readAt;
  final String? deepLink;
  final String? babyProfileId;
  final DateTime? createdAt;
  final InboxNotificationType notificationType;
  final String? actorDisplayName;

  factory InboxNotification.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at'] as String?;
    return InboxNotification(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      kind: InboxNotificationKind.fromApi(json['notification_kind'] as String?),
      params: readFeedParams(json['params']),
      readAt: json['read_at'] as String?,
      deepLink: json['deep_link'] as String?,
      babyProfileId: json['baby_profile_id']?.toString(),
      createdAt: createdRaw != null ? tryParseApiInstant(createdRaw) : null,
      notificationType: InboxNotificationType.fromApi(
        json['notification_type'] as String?,
      ),
      actorDisplayName: json['actor_display_name'] as String?,
    );
  }
}

/// The inbox unread count shown by every shell top bar (one shared value).
class UnreadInboxCount extends ChangeNotifier {
  var _count = 0;

  int get count => _count;

  void _set(int value) {
    if (value == _count) return;
    _count = value;
    notifyListeners();
  }
}

class NotificationsRepository extends ChangeNotifier {
  NotificationsRepository(this._api, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ApiClient _api;
  final DateTime Function() _clock;

  /// How long an unread count counts as current for a passive reader that
  /// mounts (the shell after the cold-start prefetch). Inbox changes still
  /// refetch at once ([notifyInboxMayHaveChanged]).
  static const unreadFreshFor = Duration(minutes: 1);

  /// Shared unread badge; refreshed through [refreshUnreadCount].
  final unread = UnreadInboxCount();
  final _unreadRequest = SingleFlight<int>();
  DateTime? _unreadFetchedAt;
  var _unreadEpoch = 0;

  /// The inbox changed (push received, row read): listeners reload and the
  /// unread badge is refetched.
  void notifyInboxMayHaveChanged() {
    notifyListeners();
    unawaited(refreshUnreadCount().catchError((Object e) {
      debugPrint('unread_count_refresh_failed: $e');
    }));
  }

  /// Refetches the unread count into [unread]. Concurrent callers share one
  /// request; with [maxAge], a count fetched within that window is kept.
  Future<void> refreshUnreadCount({Duration? maxAge}) async {
    final fetchedAt = _unreadFetchedAt;
    if (maxAge != null &&
        fetchedAt != null &&
        _clock().difference(fetchedAt) < maxAge) {
      return;
    }
    final epoch = _unreadEpoch;
    final count = await _unreadRequest.run(unreadCount);
    if (epoch != _unreadEpoch) return;
    _unreadFetchedAt = _clock();
    unread._set(count);
  }

  /// Sign-out / account deletion.
  void clearUnreadCount() {
    _unreadEpoch += 1;
    _unreadRequest.cancel();
    _unreadFetchedAt = null;
    unread._set(0);
  }

  Future<NotificationPreferences> fetchPreferences() async {
    final json = await _api.getJson('/v1/me/notification-preferences');
    return NotificationPreferences.fromJson(json);
  }

  Future<NotificationPreferences> updatePreferences({
    NotificationDigest? digest,
    bool? pushEnabled,
    bool? emailDigestEnabled,
    bool? notifyGalleryEnabled,
    bool? notifyCalendarEnabled,
    bool? notifyRegistryEnabled,
    bool? notifyCommentsEnabled,
  }) async {
    final body = <String, dynamic>{};
    if (digest != null) body['notification_digest'] = digest.apiValue;
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
    final json = await _api.patchJson(
      '/v1/me/notification-preferences',
      body: body,
    );
    return NotificationPreferences.fromJson(json);
  }

  Future<List<InboxNotification>> listInbox() async {
    final json = await _api.getJson('/v1/me/notifications');
    final page = parseOffsetPage(json, InboxNotification.fromJson);
    return page.items;
  }

  Future<void> markRead(String id) async {
    await _api.patchJson('/v1/me/notifications/$id/read', body: {});
    notifyInboxMayHaveChanged();
  }

  Future<int> markAllRead() async {
    final json = await _api.postJson('/v1/me/notifications/read-all', body: {});
    final updated = readInt(json['updated'], strict: true, field: 'updated');
    notifyInboxMayHaveChanged();
    return updated;
  }

  Future<int> unreadCount() async {
    final json = await _api.getJson('/v1/me/notifications/unread-count');
    return readInt(json['count'], strict: true, field: 'count');
  }

  Future<void> registerDeviceToken({
    required String fcmToken,
    required String platform,
  }) async {
    await _api.putJson(
      '/v1/me/device-tokens',
      body: {'fcm_token': fcmToken, 'platform': platform},
    );
  }

  Future<void> unregisterDeviceToken(String fcmToken) async {
    await _api.deleteJson(
      '/v1/me/device-tokens',
      body: {'fcm_token': fcmToken},
    );
  }
}
