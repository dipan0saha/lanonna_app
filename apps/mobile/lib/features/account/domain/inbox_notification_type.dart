/// Server-owned notification category (`notifications.notification_type`).
enum InboxNotificationType {
  photo,
  event,
  registry,
  fun,
  comment,
  squish,
  digest,
  generic;

  static InboxNotificationType fromApi(String? raw) {
    switch (raw) {
      case 'photo':
        return InboxNotificationType.photo;
      case 'event':
        return InboxNotificationType.event;
      case 'registry':
        return InboxNotificationType.registry;
      case 'fun':
        return InboxNotificationType.fun;
      case 'comment':
        return InboxNotificationType.comment;
      case 'squish':
        return InboxNotificationType.squish;
      case 'digest':
        return InboxNotificationType.digest;
      default:
        return InboxNotificationType.generic;
    }
  }
}
