import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../core/widgets/app_semantics.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    this.centerTitle = 'La Nonna',
    this.showUnreadDot = false,
    this.onSearchTap,
    this.onNotificationsTap,
    this.onProfileTap,
  });

  final String centerTitle;
  final bool showUnreadDot;
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
          AppSemantics.button(
            'shell_search',
            IconButton(
              onPressed: onSearchTap,
              icon: const Icon(Icons.search, size: 20, color: AppColors.muted),
              tooltip: 'Search',
            ),
          ),
          Expanded(
            child: AppSemantics.button(
              'shell_baby_switcher',
              GestureDetector(
                onTap: onProfileTap,
                behavior: HitTestBehavior.opaque,
                child: AppSemantics.container(
                  'shell_baby_title',
                  Text(
                    centerTitle,
                    textAlign: TextAlign.center,
                    style: titleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              AppSemantics.button(
                'shell_notifications',
                IconButton(
                  onPressed: onNotificationsTap,
                  icon: Icon(
                    Icons.notifications_outlined,
                    size: 20,
                    color: context.brand.shellIconMuted,
                  ),
                  tooltip: 'Notifications',
                ),
              ),
              if (showUnreadDot)
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
