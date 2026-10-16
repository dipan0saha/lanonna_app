import 'package:flutter/material.dart';

import '../presentation/display_initials.dart';
import '../theme/app_colors.dart';

/// Overlapping initials avatars (RSVP summary, attendees).
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.displayNames,
    this.maxVisible = 4,
    this.radius = 14,
    this.overlap = 18,
  });

  final List<String> displayNames;
  final int maxVisible;
  final double radius;
  final double overlap;

  @override
  Widget build(BuildContext context) {
    if (displayNames.isEmpty) return const SizedBox.shrink();
    final visible = displayNames.take(maxVisible).toList();
    final width = (visible.length - 1) * overlap + radius * 2;
    return SizedBox(
      height: radius * 2,
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * overlap,
              child: CircleAvatar(
                radius: radius,
                backgroundColor: AppColors.sageTint,
                child: Text(
                  displayInitials(visible[i]),
                  style: TextStyle(
                    fontSize: radius * 0.72,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
