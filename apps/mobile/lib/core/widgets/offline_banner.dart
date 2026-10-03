import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/la_nonna_theme.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.peachTint,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          "You're offline — showing saved content",
          style: context.textStyles.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.brand.ownerBadgeText,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
