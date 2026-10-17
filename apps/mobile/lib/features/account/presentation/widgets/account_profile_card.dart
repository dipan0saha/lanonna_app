import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/account_tinted_avatar.dart';
import '../../../../core/widgets/app_bordered_surface.dart';
import '../../../../core/widgets/app_semantics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../core/theme/app_button_styles.dart';
import '../../../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
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
                  OutlinedButton(onPressed: onEdit, child: Text(AppLocalizations.of(context)!.actionEdit)),
                  label: l10n.settingsEditProfile,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppSemantics.button(
                  'account_sign_out',
                  OutlinedButton(
                    onPressed: onLogOut,
                    style: AppButtonStyles.outlinedDestructive,
                    child: Text(AppLocalizations.of(context)!.accountLogOut),
                  ),
                  label: l10n.accountLogOut,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
