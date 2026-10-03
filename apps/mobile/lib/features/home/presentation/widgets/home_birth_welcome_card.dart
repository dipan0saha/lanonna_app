import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/media/cached_signed_image.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../data/models/home_summary.dart';

class HomeBirthWelcomeCard extends StatelessWidget {
  const HomeBirthWelcomeCard({
    super.key,
    required this.welcome,
    required this.babyId,
  });

  final BirthWelcomeSummary welcome;
  final String babyId;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    final brand = context.brand;

    return Container(
      margin: EdgeInsets.fromLTRB(
        AppMetrics.horizontalPadding,
        8,
        AppMetrics.horizontalPadding,
        18,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [brand.peachTint, brand.sageTint],
        ),
        borderRadius: BorderRadius.circular(AppMetrics.homeHeroRadius),
      ),
      child: Column(
        children: [
          if (welcome.photoDisplayUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedSignedImage(
                imageUrl: welcome.photoDisplayUrl,
                cacheKey: welcome.announcementId != null
                    ? 'announcement-${welcome.announcementId}'
                    : null,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          if (welcome.photoDisplayUrl != null) const SizedBox(height: 12),
          Text(
            '${welcome.babyName} is here!',
            style: text.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Day ${welcome.daysSinceBirth + 1} — share the keepsake with family.',
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/baby/$babyId/announcement'),
                  child: const Text('View card'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
