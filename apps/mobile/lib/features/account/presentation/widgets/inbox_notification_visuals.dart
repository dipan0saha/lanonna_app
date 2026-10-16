import 'package:flutter/material.dart';

import '../../../../core/widgets/tinted_icon_square.dart';
import '../../domain/inbox_notification_type.dart';

class InboxNotificationVisual {
  const InboxNotificationVisual({required this.icon, this.emoji});

  final IconData icon;
  final String? emoji;
}

InboxNotificationVisual inboxNotificationVisualForType(
  InboxNotificationType type,
) {
  return switch (type) {
    InboxNotificationType.photo => const InboxNotificationVisual(
      icon: Icons.photo_outlined,
      emoji: '📷',
    ),
    InboxNotificationType.event => const InboxNotificationVisual(
      icon: Icons.event_outlined,
      emoji: '📅',
    ),
    InboxNotificationType.registry => const InboxNotificationVisual(
      icon: Icons.card_giftcard_outlined,
      emoji: '🎁',
    ),
    InboxNotificationType.fun => const InboxNotificationVisual(
      icon: Icons.emoji_events_outlined,
      emoji: '⭐',
    ),
    InboxNotificationType.comment => const InboxNotificationVisual(
      icon: Icons.chat_bubble_outline,
      emoji: '💬',
    ),
    InboxNotificationType.squish => const InboxNotificationVisual(
      icon: Icons.back_hand_outlined,
      emoji: '👋',
    ),
    InboxNotificationType.digest => const InboxNotificationVisual(
      icon: Icons.notifications_outlined,
      emoji: '🔔',
    ),
    InboxNotificationType.generic => const InboxNotificationVisual(
      icon: Icons.notifications_outlined,
      emoji: '🔔',
    ),
  };
}

Widget inboxNotificationLeading(InboxNotificationVisual visual) {
  return TintedIconSquare(icon: visual.icon, emoji: visual.emoji);
}
