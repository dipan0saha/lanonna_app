import 'package:flutter/material.dart';

import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';

/// Two equal-width CTAs in a row, or a vertical stack below [AppMetrics.responsiveButtonPairBreakpoint].
class AppResponsiveButtonPair extends StatelessWidget {
  const AppResponsiveButtonPair({
    super.key,
    required this.start,
    this.end,
    this.spacing,
  });

  final Widget start;
  final Widget? end;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final gap = spacing ?? AppSpacing.smMd;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackVertically =
            constraints.maxWidth < AppMetrics.responsiveButtonPairBreakpoint ||
            end == null;
        if (stackVertically) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              start,
              if (end != null) ...[SizedBox(height: gap), end!],
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: start),
            SizedBox(width: gap),
            Expanded(child: end!),
          ],
        );
      },
    );
  }
}
