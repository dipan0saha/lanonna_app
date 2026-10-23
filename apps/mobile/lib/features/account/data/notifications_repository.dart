import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lanonna/features/account/domain/notification_digest.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/cursor_page.dart';
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
    required this.notifyGalleryEnabled,
    required this.notifyCalendarEnabled,
    required this.notifyRegistryEnabled,
    required this.notifyCommentsEnabled,
  });

  final NotificationDigest digest;
  final bool pushEnabled;
  final bool notifyGalleryEnabled;
  final bool notifyCalendarEnabled;
  final bool notifyRegistryEnabled;
  final bool notifyCommentsEnabled;

  NotificationPreferences copyWith({
    NotificationDigest? digest,
    bool? pushEnabled,
    bool? notifyGalleryEnabled,
    bool? notifyCalendarEnabled,
    bool? notifyRegistryEnabled,
    bool? notifyCommentsEnabled,
  }) {
    return NotificationPreferences(
      digest: digest ?? this.digest,
      pushEnabled: pushEnabled ?? this.pushEnabled,
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

  /// This row with [readAt] replaced (null marks it unread).
  InboxNotification withReadAt(String? readAt) {
    return InboxNotification(
      id: id,
      title: title,
      body: body,
      kind: kind,
      params: params,
      readAt: readAt,
      deepLink: deepLink,
      babyProfileId: babyProfileId,
      createdAt: createdAt,
      notificationType: notificationType,
      actorDisplayName: actorDisplayName,
    );
  }

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

/// Loaded inbox rows for the signed-in user (newest first).
class InboxListWindow {
  const InboxListWindow({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<InboxNotification> items;
  final bool hasMore;
  final String? nextCursor;
}

class NotificationsRepository extends ChangeNotifier {
  NotificationsRepository(this._api, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ApiClient _api;
  final DateTime Function() _clock;

  static const inboxFreshFor = Duration(minutes: 2);
  static const inboxPageSize = 50;

  /// How long an unread count counts as current for a passive reader that
  /// mounts (the shell after the cold-start prefetch). Inbox changes still
  /// refetch at once ([notifyInboxMayHaveChanged]).
  static const unreadFreshFor = Duration(minutes: 1);

  /// Shared unread badge; refreshed through [refreshUnreadCount].
  final unread = UnreadInboxCount();
  final _unreadRequest = SingleFlight<int>();
  DateTime? _unreadFetchedAt;
  var _unreadEpoch = 0;

  InboxListWindow? _inboxWindow;
  DateTime? _inboxFetchedAt;
  var _inboxEpoch = 0;
  final _inboxFirstPage = SingleFlight<void>();
  final _inboxExtend = SingleFlight<void>();

  /// Rows marked read locally whose PATCH has not settled; a page fetched
  /// meanwhile still shows them read.
  final _pendingReadIds = <String>{};

  InboxListWindow? peekInbox() => _inboxWindow;

  bool get isInboxFresh {
    final fetchedAt = _inboxFetchedAt;
    return _inboxWindow != null &&
        fetchedAt != null &&
        _clock().difference(fetchedAt) < inboxFreshFor;
  }

  /// Push or external change: keep the visible list, refetch badge, let screens
  /// revalidate the inbox in the background.
  void notifyInboxMayHaveChanged() {
    _inboxFetchedAt = null;
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
    clearCachedInbox();
  }

  void clearCachedInbox() {
    _inboxEpoch += 1;
    _inboxWindow = null;
    _inboxFetchedAt = null;
    _pendingReadIds.clear();
    _inboxFirstPage.cancel();
    _inboxExtend.cancel();
  }

  Future<NotificationPreferences> fetchPreferences() async {
    final json = await _api.getJson('/v1/me/notification-preferences');
    return NotificationPreferences.fromJson(json);
  }

  Future<NotificationPreferences> updatePreferences({
    NotificationDigest? digest,
    bool? pushEnabled,
    bool? notifyGalleryEnabled,
    bool? notifyCalendarEnabled,
    bool? notifyRegistryEnabled,
    bool? notifyCommentsEnabled,
  }) async {
    final body = <String, dynamic>{};
    if (digest != null) body['notification_digest'] = digest.apiValue;
    if (pushEnabled != null) body['push_notifications_enabled'] = pushEnabled;
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

  /// First inbox page: from memory when fresh, else from the network.
  Future<InboxListWindow> ensureInboxFirstPage({bool forceRefresh = false}) async {
    final cached = _inboxWindow;
    if (!forceRefresh && isInboxFresh && cached != null) return cached;
    await _inboxFirstPage.run(_fetchInboxFirstPage);
    // Null only when a sign-out cleared the cache mid-request.
    return _inboxWindow ?? const InboxListWindow(items: [], hasMore: false);
  }

  /// Stale-while-revalidate: callers show [peekInbox] and call this to
  /// refetch the first page in the background.
  Future<void> revalidateInbox() => _inboxFirstPage.run(_fetchInboxFirstPage);

  Future<void> extendInbox() {
    final window = _inboxWindow;
    if (window == null || !window.hasMore) return Future.value();
    return _inboxExtend.run(_fetchInboxNextPage);
  }

  Future<void> _fetchInboxFirstPage() async {
    final epoch = _inboxEpoch;
    try {
      final page = await _fetchInboxPage();
      if (epoch != _inboxEpoch) return;
      _inboxWindow = _mergeFirstPage(page, _inboxWindow);
      _inboxFetchedAt = _clock();
      notifyListeners();
    } catch (e) {
      if (epoch != _inboxEpoch) return;
      final cached = _inboxWindow;
      if (cached != null && cached.items.isNotEmpty && _shouldServeStaleInbox(e)) {
        return;
      }
      rethrow;
    }
  }

  /// A refreshed first page replaces the head of the window. When its last row
  /// is still in the loaded window, the older rows after it (and their cursor)
  /// are kept, so revalidating does not drop pages the user already scrolled
  /// through. Keyset order only gains rows at the head, so that tail is
  /// exactly the continuation of the new page.
  static InboxListWindow _mergeFirstPage(
    CursorPage<InboxNotification> page,
    InboxListWindow? previous,
  ) {
    final fresh = InboxListWindow(
      items: page.items,
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
    );
    if (previous == null || !page.hasMore || page.items.isEmpty) return fresh;
    final tailId = page.items.last.id;
    final at = previous.items.indexWhere((n) => n.id == tailId);
    if (at < 0 || at == previous.items.length - 1) return fresh;
    return InboxListWindow(
      items: [...page.items, ...previous.items.skip(at + 1)],
      hasMore: previous.hasMore,
      nextCursor: previous.nextCursor,
    );
  }

  Future<void> _fetchInboxNextPage() async {
    final epoch = _inboxEpoch;
    final cursor = _inboxWindow?.nextCursor;
    if (cursor == null || !(_inboxWindow?.hasMore ?? false)) return;
    final page = await _fetchInboxPage(cursor: cursor);
    final window = _inboxWindow;
    // A sign-out, or a refresh that replaced the tail, makes this page stale.
    if (epoch != _inboxEpoch || window == null || window.nextCursor != cursor) {
      return;
    }
    final existingIds = window.items.map((n) => n.id).toSet();
    _inboxWindow = InboxListWindow(
      items: [
        ...window.items,
        ...page.items.where((n) => !existingIds.contains(n.id)),
      ],
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
    );
    notifyListeners();
  }

  Future<CursorPage<InboxNotification>> _fetchInboxPage({String? cursor}) async {
    final suffix = cursor == null
        ? '?limit=$inboxPageSize'
        : '?limit=$inboxPageSize&cursor=${Uri.encodeQueryComponent(cursor)}';
    final json = await _api.getJson('/v1/me/notifications$suffix');
    final page = parseCursorPage(
      json,
      InboxNotification.fromJson,
      defaultLimit: inboxPageSize,
    );
    if (_pendingReadIds.isEmpty) return page;
    final readAt = toApiInstant(_clock());
    return CursorPage(
      items: [
        for (final n in page.items)
          n.readAt == null && _pendingReadIds.contains(n.id)
              ? n.withReadAt(readAt)
              : n,
      ],
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
      limit: page.limit,
    );
  }

  static bool _shouldServeStaleInbox(Object error) {
    if (error is ApiException) {
      final code = error.statusCode;
      if (code != null && code >= 400 && code < 500) return false;
    }
    return true;
  }

  /// Optimistic: the row and the unread badge update before the request, and
  /// both are restored if it fails.
  Future<void> markRead(String id) async {
    final previous = _setInboxRow(id, read: true);
    final wasUnread = previous != null && previous.readAt == null;
    // A count fetched before this PATCH lands would resurrect the badge.
    _unreadEpoch += 1;
    _unreadRequest.cancel();
    if (wasUnread) unread._set(unread.count > 0 ? unread.count - 1 : 0);
    _pendingReadIds.add(id);
    try {
      await _api.patchJson('/v1/me/notifications/$id/read', body: {});
      _pendingReadIds.remove(id);
      if (previous == null) {
        // Row was not loaded, so its read state was unknown; ask the server.
        _unreadFetchedAt = null;
        unawaited(refreshUnreadCount().catchError((Object e) {
          debugPrint('unread_count_refresh_failed: $e');
        }));
      } else {
        _unreadFetchedAt = _clock();
      }
    } catch (e) {
      if (_pendingReadIds.remove(id) && wasUnread) {
        _setInboxRow(id, read: false);
        unread._set(unread.count + 1);
      }
      rethrow;
    }
  }

  Future<int> markAllRead() async {
    final json = await _api.postJson('/v1/me/notifications/read-all', body: {});
    final updated = readInt(json['updated'], strict: true, field: 'updated');
    _unreadEpoch += 1;
    _unreadRequest.cancel();
    _markAllReadLocal();
    unread._set(0);
    _unreadFetchedAt = _clock();
    notifyListeners();
    return updated;
  }

  /// Sets one loaded row's read state; returns the row as it was, or null
  /// when it is not in the window.
  InboxNotification? _setInboxRow(String id, {required bool read}) {
    final window = _inboxWindow;
    if (window == null) return null;
    final index = window.items.indexWhere((n) => n.id == id);
    if (index < 0) return null;
    final row = window.items[index];
    if ((row.readAt != null) == read) return row;
    final items = [...window.items];
    items[index] = row.withReadAt(read ? toApiInstant(_clock()) : null);
    _inboxWindow = InboxListWindow(
      items: items,
      hasMore: window.hasMore,
      nextCursor: window.nextCursor,
    );
    notifyListeners();
    return row;
  }

  void _markAllReadLocal() {
    final window = _inboxWindow;
    if (window == null) return;
    final readAt = toApiInstant(_clock());
    _inboxWindow = InboxListWindow(
      items: window.items
          .map((n) => n.readAt == null ? n.withReadAt(readAt) : n)
          .toList(),
      hasMore: window.hasMore,
      nextCursor: window.nextCursor,
    );
    _inboxFetchedAt = _clock();
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
