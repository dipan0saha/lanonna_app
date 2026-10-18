import 'package:flutter/material.dart';
import '../media/cached_signed_image.dart';
import '../theme/app_colors.dart';
import 'avatar_initials.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';

/// Gradient-ring avatar with initials (account header, shell).
class AccountTintedAvatar extends StatelessWidget {
  const AccountTintedAvatar({
    super.key,
    required this.displayName,
    this.fallbackText,
    this.imageUrl,
    this.radius = AppMetrics.accountProfileAvatarRadius,
  });

  final String? displayName;

  /// Used for the initials when [displayName] is blank (the sign-in email).
  final String? fallbackText;
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
          ? CachedSignedImage(
              imageUrl: url,
              width: size,
              height: size,
              // Same look as before: the ring shows while loading, the photo
              // appears without a fade, initials if it fails.
              placeholder: (_) => const SizedBox.shrink(),
              error: _initials,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
            )
          : _initials(context),
    );
  }

  Widget _initials(BuildContext context) {
    return Center(
      child: AvatarInitials(
        name: displayName,
        fallbackText: fallbackText,
        style: context.textStyles.titleMedium?.copyWith(
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}
