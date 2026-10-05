import 'package:flutter/material.dart';

import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';

/// Home scroll section title row (uppercase label + optional trailing action).
///
/// Applies [AppMetrics.horizontalPadding] once. Do not wrap in extra horizontal
/// [Padding] at call sites.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.action,
  });

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppMetrics.horizontalPadding,
        0,
        AppMetrics.horizontalPadding,
        10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: context.textStyles.labelSmall,
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
