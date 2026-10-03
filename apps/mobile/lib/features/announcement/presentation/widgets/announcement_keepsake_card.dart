import 'package:flutter/material.dart';

import '../../../../core/media/cached_signed_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../data/announcement_repository.dart';

class AnnouncementKeepsakeCard extends StatelessWidget {
  const AnnouncementKeepsakeCard({super.key, required this.detail});

  final AnnouncementDetail detail;

  Color _cardTint(String? gender) {
    if (gender == 'female') return AppColors.peachTint;
    if (gender == 'male') return AppColors.sageTint;
    return AppColors.sageTint;
  }

  @override
  Widget build(BuildContext context) {
    final d = detail;
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: _cardTint(d.gender),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (d.photoDisplayUrl != null)
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryDark, width: 3),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedSignedImage(
                imageUrl: d.photoDisplayUrl,
                cacheKey: 'announcement-photo-${d.id}',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            )
          else
            const CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.surface,
              child: Icon(Icons.child_care, size: 36, color: AppColors.primaryDark),
            ),
          const SizedBox(height: 12),
          Text(
            d.firstName ?? 'Baby',
            style: context.textStyles.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (d.lastName != null && d.lastName!.isNotEmpty)
            Text(
              d.lastName!.toUpperCase(),
              style: context.textStyles.titleSmall?.copyWith(letterSpacing: 1.2),
            ),
          const SizedBox(height: 12),
          if (d.birthDate != null)
            Text(d.birthDate!, style: context.textStyles.bodySmall),
        ],
      ),
    );
  }
}
