import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';

class InboxNotificationVisual {
  const InboxNotificationVisual({required this.icon, this.emoji});

  final IconData icon;
  final String? emoji;
}

InboxNotificationVisual inboxNotificationVisual({
  required String? deepLink,
  required String title,
  required String body,
}) {
  final link = deepLink?.toLowerCase() ?? '';
  final haystack = '${title.toLowerCase()} ${body.toLowerCase()}';
  if (link.contains('/gallery') || haystack.contains('photo')) {
    return const InboxNotificationVisual(
      icon: Icons.photo_outlined,
      emoji: '📷',
    );
  }
  if (link.contains('/calendar') ||
      haystack.contains('event') ||
      haystack.contains('rsvp')) {
    return const InboxNotificationVisual(
      icon: Icons.event_outlined,
      emoji: '📅',
    );
  }
  if (link.contains('/registry') || haystack.contains('registry')) {
    return const InboxNotificationVisual(
      icon: Icons.card_giftcard_outlined,
      emoji: '🎁',
    );
  }
  if (link.contains('/fun') ||
      link.contains('gamification') ||
      haystack.contains('name') ||
      haystack.contains('vote')) {
    return const InboxNotificationVisual(
      icon: Icons.emoji_events_outlined,
      emoji: '⭐',
    );
  }
  if (haystack.contains('comment')) {
    return const InboxNotificationVisual(
      icon: Icons.chat_bubble_outline,
      emoji: '💬',
    );
  }
  if (haystack.contains('squish')) {
    return const InboxNotificationVisual(
      icon: Icons.back_hand_outlined,
      emoji: '👋',
    );
  }
  return const InboxNotificationVisual(
    icon: Icons.notifications_outlined,
    emoji: '🔔',
  );
}

/// Leading tinted square for an inbox row.
Widget inboxNotificationLeading(InboxNotificationVisual visual) {
  return Container(
    width: AppMetrics.tintedIconSquareSize,
    height: AppMetrics.tintedIconSquareSize,
    decoration: BoxDecoration(
      color: AppColors.sageTint,
      borderRadius: BorderRadius.circular(AppMetrics.tintedIconSquareRadius),
    ),
    alignment: Alignment.center,
    child: visual.emoji != null
        ? Text(visual.emoji!, style: const TextStyle(fontSize: 18))
        : Icon(
            visual.icon,
            size: AppMetrics.tintedIconSquareIconSize,
            color: AppColors.primaryDark,
          ),
  );
}

String? inboxNotificationActorName({required String title, required String body}) {
  final trimmedTitle = title.trim();
  if (trimmedTitle.isNotEmpty &&
      !_genericNotificationTitles.contains(trimmedTitle.toLowerCase())) {
    return trimmedTitle;
  }
  final match = RegExp(r'^([^:]+)\s').firstMatch(body.trim());
  if (match != null) {
    final candidate = match.group(1)?.trim();
    if (candidate != null && candidate.isNotEmpty) return candidate;
  }
  return null;
}

const _genericNotificationTitles = {
  'new comment',
  'new squish',
  'new rsvp',
  'registry update',
  'calendar reminder',
  'notification',
};
