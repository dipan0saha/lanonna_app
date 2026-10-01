import 'package:flutter/material.dart';

import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';

class HomeSectionLabel extends StatelessWidget {
  const HomeSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final String? trailing;

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
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: context.textStyles.labelSmall,
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: context.textStyles.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
