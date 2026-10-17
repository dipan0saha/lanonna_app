import 'package:flutter/material.dart';

import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../l10n/app_localizations.dart';

class OnboardingLogoMark extends StatelessWidget {
  const OnboardingLogoMark({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = context.textStyles;
    return Column(
      children: [
        Text(
          l10n.appTitle,
          style: text.headlineLarge,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.labelPrivateOrganizedConnected,
          style: text.labelSmall?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
