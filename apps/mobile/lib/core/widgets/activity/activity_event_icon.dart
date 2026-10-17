import 'package:flutter/material.dart';

import '../../domain/activity_event_type.dart';
import '../../theme/app_colors.dart';

class ActivityEventIcon extends StatelessWidget {
  const ActivityEventIcon({super.key, required this.eventType});

  final ActivityEventType? eventType;

  @override
  Widget build(BuildContext context) {
    final icon = _iconFor(eventType);
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: AppColors.inputFill,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: AppColors.textPrimary),
    );
  }

  IconData _iconFor(ActivityEventType? type) => switch (type) {
        ActivityEventType.photoSquish => Icons.volunteer_activism_outlined,
        ActivityEventType.photoComment => Icons.chat_bubble_outline,
        ActivityEventType.photoShared => Icons.photo_camera_outlined,
        ActivityEventType.registryItemAdded ||
        ActivityEventType.registryPurchased ||
        ActivityEventType.registryClaimed =>
          Icons.card_giftcard_outlined,
        ActivityEventType.eventCreated => Icons.event_outlined,
        ActivityEventType.nameSuggested => Icons.star_outline,
        ActivityEventType.genderVoteCast => Icons.how_to_vote_outlined,
        ActivityEventType.babyArrived => Icons.celebration_outlined,
        ActivityEventType.memberRemoved ||
        ActivityEventType.memberLeft =>
          Icons.group_outlined,
        null => Icons.notifications_none_outlined,
      };
}
