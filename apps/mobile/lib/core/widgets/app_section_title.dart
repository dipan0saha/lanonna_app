import 'package:flutter/material.dart';

import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';

/// Block section title on scrollable subpages (title → content gap built in).
///
/// For home tab sections use `HomeSectionHeader`. For form field labels use
/// `OnboardingFieldLabel` / `AppLabeledTextField`.
class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({
    super.key,
    required this.title,
    this.action,
    this.style,
  });

  final String title;
  final Widget? action;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? context.textStyles.labelLarge;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppMetrics.sectionTitleGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(title, style: textStyle)),
          if (action != null) action!,
        ],
      ),
    );
  }
}
