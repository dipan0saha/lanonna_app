import 'package:flutter/material.dart';

import '../../../../core/media/cached_signed_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../onboarding/presentation/widgets/onboarding_typography.dart';

/// Full-width cover picker row from calendar prototype (`cal-new` photo upload).
class PrototypeEventCoverUpload extends StatelessWidget {
  const PrototypeEventCoverUpload({
    super.key,
    required this.onTap,
    this.previewImageUrl,
    this.cacheKey,
  });

  final VoidCallback? onTap;
  final String? previewImageUrl;
  final String? cacheKey;

  @override
  Widget build(BuildContext context) {
    final url = previewImageUrl?.trim();
    final hasPreview = url != null && url.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const OnboardingFieldLabel('Photo (optional)'),
        const SizedBox(height: AppMetrics.fieldLabelGap),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFFF1F1F2),
              border: Border.all(color: const Color(0xFFCFCFD1), width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasPreview
                ? CachedSignedImage(
                    imageUrl: url,
                    cacheKey: cacheKey ?? 'event-cover-$url',
                    width: double.infinity,
                    height: 70,
                    fit: BoxFit.cover,
                  )
                : const Center(
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 26,
                      color: AppColors.muted,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: AppMetrics.formFieldSpacing),
      ],
    );
  }
}
