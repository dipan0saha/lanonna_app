import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/la_nonna_theme.dart';

class GalleryEmptyState extends StatelessWidget {
  const GalleryEmptyState({
    super.key,
    required this.isOwner,
    this.onAddPhoto,
  });

  final bool isOwner;
  final VoidCallback? onAddPhoto;

  @override
  Widget build(BuildContext context) {
    final styles = context.textStyles;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.peachTint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.photo_outlined, color: AppColors.primary, size: 34),
          ),
          const SizedBox(height: 16),
          Text('No photos yet', style: styles.titleMedium),
          const SizedBox(height: 8),
          Text(
            isOwner
                ? 'Add your first photo to start sharing your baby\'s journey with family.'
                : 'Once a photo is shared, it will show up here for everyone to enjoy.',
            textAlign: TextAlign.center,
            style: styles.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          if (isOwner && onAddPhoto != null) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onAddPhoto,
              child: const Text('+ Add Photo'),
            ),
          ],
        ],
      ),
    );
  }
}
