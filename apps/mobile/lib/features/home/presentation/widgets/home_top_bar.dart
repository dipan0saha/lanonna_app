import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../core/widgets/account_tinted_avatar.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_semantics.dart';
import '../../../../core/widgets/app_unread_dot.dart';
import '../../../../l10n/app_localizations.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    this.centerTitle,
    this.showUnreadDot = false,
    this.onAddBabyTap,
    this.onInviteFamilyTap,
    this.onBabySwitcherTap,
    this.onNotificationsTap,
    this.onAccountTap,
    this.accountDisplayName,
    this.accountAvatarUrl,
  });

  /// Selected baby name; the app title when null.
  final String? centerTitle;
  final bool showUnreadDot;
  final VoidCallback? onAddBabyTap;
  final VoidCallback? onInviteFamilyTap;
  final VoidCallback? onBabySwitcherTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onAccountTap;
  final String? accountDisplayName;
  final String? accountAvatarUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppMetrics.horizontalPadding,
        AppMetrics.shellTopBarTopInset,
        AppMetrics.horizontalPadding,
        AppMetrics.shellTopBarBottomInset,
      ),
      child: Row(
        children: [
          _ShellLeadingIconButton(
            semanticsId: 'shell_add_baby',
            label: l10n.actionAddBaby2,
            onPressed: onAddBabyTap,
            icon: Icon(
              Icons.add,
              size: AppMetrics.shellAddIconSize,
              color: AppColors.textPrimary,
            ),
          ),
          _ShellLeadingIconButton(
            semanticsId: 'shell_invite_family',
            label: l10n.actionInviteFriends,
            onPressed: onInviteFamilyTap,
            icon: Icon(
              Icons.group_add_outlined,
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
                          centerTitle ?? AppLocalizations.of(context)!.appTitle,
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
              label: l10n.actionSwitchBabyProfile,
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              AppIconButton(
                semanticsId: 'shell_notifications',
                label: l10n.notificationsInboxTitle,
                onPressed: onNotificationsTap,
                icon: Icon(
                  Icons.notifications_outlined,
                  size: AppMetrics.shellIconSize,
                  color: context.brand.shellIconMuted,
                ),
              ),
              if (showUnreadDot)
                const Positioned(
                  right: AppSpacing.sm,
                  top: AppSpacing.sm,
                  child: AppUnreadDot(),
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
            label: l10n.labelMyAccount,
          ),
        ],
      ),
    );
  }
}

class _ShellLeadingIconButton extends StatelessWidget {
  const _ShellLeadingIconButton({
    required this.semanticsId,
    required this.label,
    required this.onPressed,
    required this.icon,
  });

  final String semanticsId;
  final String label;
  final VoidCallback? onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppMetrics.shellLeadingSlotWidth,
      height: AppMetrics.shellLeadingSlotWidth,
      child: AppIconButton(
        semanticsId: semanticsId,
        label: label,
        onPressed: onPressed,
        padding: AppMetrics.shellLeadingIconButtonPadding,
        constraints: const BoxConstraints(
          minWidth: AppMetrics.shellLeadingSlotWidth,
          minHeight: AppMetrics.shellLeadingSlotWidth,
        ),
        icon: icon,
      ),
    );
  }
}
