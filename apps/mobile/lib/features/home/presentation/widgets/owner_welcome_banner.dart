import 'package:flutter/material.dart';

import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';

class OwnerWelcomeBanner extends StatelessWidget {
  const OwnerWelcomeBanner({super.key, required this.babyName});

  final String babyName;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final text = context.textStyles;

    return Container(
      margin: EdgeInsets.fromLTRB(
        AppMetrics.horizontalPadding,
        8,
        AppMetrics.horizontalPadding,
        18,
      ),
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brand.peachTint, brand.sageTint],
        ),
        borderRadius: BorderRadius.circular(AppMetrics.homeHeroRadius),
      ),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 34)),
          const SizedBox(height: 8),
          Text(
            '$babyName is here!',
            style: text.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            "Everyone you've invited has been notified. Updates will show up here.",
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
        ],
      ),
    );
  }
}
