import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    this.onSearchTap,
    this.onNotificationsTap,
    this.onProfileTap,
  });

  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final titleStyle = context.textStyles.titleMedium;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppMetrics.horizontalPadding,
        2,
        AppMetrics.horizontalPadding,
        14,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onSearchTap,
            icon: const Icon(Icons.search, size: 20, color: AppColors.muted),
            tooltip: 'Search',
          ),
          Expanded(
            child: GestureDetector(
              onTap: onProfileTap,
              behavior: HitTestBehavior.opaque,
              child: Text(
                'La Nonna',
                textAlign: TextAlign.center,
                style: titleStyle,
              ),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onNotificationsTap,
                icon: Icon(
                  Icons.notifications_outlined,
                  size: 20,
                  color: context.brand.shellIconMuted,
                ),
                tooltip: 'Notifications',
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.secondaryDark,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
