import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../presentation/display_initials.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';

/// Gradient-ring avatar with initials (account header, shell).
class AccountTintedAvatar extends StatelessWidget {
  const AccountTintedAvatar({
    super.key,
    required this.displayName,
    this.imageUrl,
    this.radius = AppMetrics.accountProfileAvatarRadius,
  });

  final String? displayName;
  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final size = radius * 2;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [context.brand.sageTint, context.brand.peachTint],
        ),
        border: Border.all(color: AppColors.surface, width: 1.5),
        boxShadow: [BoxShadow(color: AppColors.border, spreadRadius: 0.5)],
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _initials(context),
            )
          : _initials(context),
    );
  }

  Widget _initials(BuildContext context) {
    return Center(
      child: Text(
        displayInitials(displayName ?? AppLocalizations.of(context)!.commonMe),
        style: context.textStyles.titleMedium?.copyWith(
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}
