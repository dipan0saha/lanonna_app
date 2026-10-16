import 'package:flutter/material.dart';

import '../../../../core/presentation/display_initials.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
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
    final titleStyle = context.textStyles.titleSmall?.copyWith(
      fontSize: 17,
      color: AppColors.textPrimary,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppMetrics.horizontalPadding,
        2,
        AppMetrics.horizontalPadding,
        14,
      ),
      child: Row(
        children: [
          AppIconButton(
            semanticsId: 'shell_add_baby',
            label: 'Add baby',
            onPressed: onAddBabyTap,
            icon: const Icon(Icons.add, size: 22, color: AppColors.textPrimary),
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
                          style: titleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
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
                size: 20,
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
                  size: 20,
                  color: context.brand.shellIconMuted,
                ),
              ),
              if (showUnreadDot)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryDark,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
          AppSemantics.button(
            'shell_account',
            GestureDetector(
              onTap: onAccountTap,
              child: _AccountAvatar(
                displayName: accountDisplayName,
                avatarUrl: accountAvatarUrl,
              ),
            ),
            label: 'My account',
          ),
        ],
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({this.displayName, this.avatarUrl});

  final String? displayName;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [context.brand.sageTint, context.brand.peachTint],
        ),
        border: Border.all(color: AppColors.surface, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.border,
            spreadRadius: 0.5,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.isNotEmpty
          ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
              return _initials(displayName);
            })
          : _initials(displayName),
    );
  }

  Widget _initials(String? name) {
    return Center(
      child: Text(
        displayInitials(name ?? 'Me'),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}
