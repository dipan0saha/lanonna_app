import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../core/widgets/account_tinted_avatar.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_semantics.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    this.centerTitle = 'La Nonna',
    this.showUnreadDot = false,
    this.onAddBabyTap,
    this.onBabySwitcherTap,
    this.onSearchTap,
    this.onNotificationsTap,
    this.onAccountTap,
    this.accountDisplayName,
    this.accountAvatarUrl,
  });

  final String centerTitle;
  final bool showUnreadDot;
  final VoidCallback? onAddBabyTap;
  final VoidCallback? onBabySwitcherTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onAccountTap;
  final String? accountDisplayName;
  final String? accountAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppMetrics.horizontalPadding,
        AppMetrics.shellTopBarTopInset,
        AppMetrics.horizontalPadding,
        AppMetrics.shellTopBarBottomInset,
      ),
      child: Row(
        children: [
          AppIconButton(
            semanticsId: 'shell_add_baby',
            label: 'Add baby',
            onPressed: onAddBabyTap,
            icon: Icon(
              Icons.add,
              size: AppMetrics.shellAddIconSize,
              color: AppColors.textPrimary,
            ),
          ),
          Expanded(
            child: AppSemantics.button(
              'shell_baby_switcher',
              GestureDetector(
                onTap: onBabySwitcherTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: AppSemantics.container(
                        'shell_baby_title',
                        Text(
                          centerTitle,
                          textAlign: TextAlign.center,
                          style: context.shellBabySwitcherTitleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.xxs),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: AppMetrics.shellIconSize,
                      color: AppColors.textPrimary,
                    ),
                  ],
                ),
              ),
              label: 'Switch baby profile',
            ),
          ),
          if (onSearchTap != null)
            AppIconButton(
              semanticsId: 'shell_search',
              label: 'Search',
              onPressed: onSearchTap,
              icon: Icon(
                Icons.search,
                size: AppMetrics.shellIconSize,
                color: context.brand.shellIconMuted,
              ),
            ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              AppIconButton(
                semanticsId: 'shell_notifications',
                label: 'Notifications',
                onPressed: onNotificationsTap,
                icon: Icon(
                  Icons.notifications_outlined,
                  size: AppMetrics.shellIconSize,
                  color: context.brand.shellIconMuted,
                ),
              ),
              if (showUnreadDot)
                Positioned(
                  right: AppSpacing.sm,
                  top: AppSpacing.sm,
                  child: Container(
                    width: AppMetrics.shellUnreadDotSize,
                    height: AppMetrics.shellUnreadDotSize,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryDark,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.surface,
                        width: AppMetrics.shellUnreadDotBorderWidth,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: AppSpacing.xs),
          AppSemantics.button(
            'shell_account',
            GestureDetector(
              onTap: onAccountTap,
              child: AccountTintedAvatar(
                displayName: accountDisplayName,
                imageUrl: accountAvatarUrl,
                radius: AppMetrics.shellAccountAvatarSize / 2,
              ),
            ),
            label: 'My account',
          ),
        ],
      ),
    );
  }
}
