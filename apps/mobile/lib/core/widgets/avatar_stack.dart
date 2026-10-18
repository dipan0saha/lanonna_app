import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/la_nonna_theme.dart';
import 'avatar_initials.dart';

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
                child: AvatarInitials(
                  name: visible[i],
                  style: context.textStyles.labelSmall?.copyWith(
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
