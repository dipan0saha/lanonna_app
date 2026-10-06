import 'package:flutter/material.dart';

import '../../../../core/theme/la_nonna_theme.dart';

class OnboardingLogoMark extends StatelessWidget {
  const OnboardingLogoMark({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    return Column(
      children: [
        Text(
          'La Nonna',
          style: text.headlineLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'PRIVATE. ORGANIZED. CONNECTED.',
          style: text.labelSmall?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
