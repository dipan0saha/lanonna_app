import 'package:flutter/material.dart';

import 'onboarding_typography.dart';

/// Headline + support copy block for carousel slides (below art, above dots).
class OnboardingCarouselCaption extends StatelessWidget {
  const OnboardingCarouselCaption({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingHeadline(title, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OnboardingSupportText(body, textAlign: TextAlign.center),
      ],
    );
  }
}
