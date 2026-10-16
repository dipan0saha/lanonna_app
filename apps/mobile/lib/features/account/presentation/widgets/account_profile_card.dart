import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/account_tinted_avatar.dart';
import '../../../../core/widgets/app_bordered_surface.dart';
import '../../../../core/widgets/app_semantics.dart';
import '../../../../core/theme/la_nonna_theme.dart';

class AccountProfileCard extends StatelessWidget {
  const AccountProfileCard({
    super.key,
    required this.displayName,
    this.email,
    this.avatarUrl,
    required this.onEdit,
    required this.onLogOut,
  });

  final String displayName;
  final String? email;
  final String? avatarUrl;
  final VoidCallback onEdit;
  final VoidCallback onLogOut;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    return AppBorderedSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          AccountTintedAvatar(displayName: displayName, imageUrl: avatarUrl),
          SizedBox(height: AppSpacing.md),
          Text(displayName, style: context.accountProfileNameStyle),
          if (email != null) ...[
            SizedBox(height: AppSpacing.xxs),
            Text(
              email!,
              style: text.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
          SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppSemantics.button(
                  'account_edit_profile',
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                    ),
                    onPressed: onEdit,
                    child: const Text('Edit'),
                  ),
                  label: 'Edit profile',
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppSemantics.button(
                  'account_sign_out',
                  OutlinedButton(
                    onPressed: onLogOut,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Log Out'),
                  ),
                  label: 'Log Out',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
