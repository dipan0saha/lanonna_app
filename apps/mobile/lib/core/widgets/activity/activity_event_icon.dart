import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class ActivityEventIcon extends StatelessWidget {
  const ActivityEventIcon({super.key, required this.eventType});

  final String eventType;

  @override
  Widget build(BuildContext context) {
    final icon = _iconFor(eventType);
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F1F2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: AppColors.textPrimary),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'photo_squish':
        return Icons.volunteer_activism_outlined;
      case 'photo_comment':
        return Icons.chat_bubble_outline;
      case 'photo_shared':
        return Icons.photo_camera_outlined;
      case 'registry_item_added':
      case 'registry_purchased':
        return Icons.card_giftcard_outlined;
      case 'event_created':
        return Icons.event_outlined;
      case 'name_suggested':
        return Icons.star_outline;
      case 'gender_vote_cast':
        return Icons.how_to_vote_outlined;
      case 'baby_arrived':
        return Icons.celebration_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }
}
