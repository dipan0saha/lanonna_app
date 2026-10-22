import 'package:flutter/material.dart';

import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';

/// Two equal-width CTAs in a row, or a vertical stack below [breakpoint]
/// (default [AppMetrics.responsiveButtonPairBreakpoint]).
class AppResponsiveButtonPair extends StatelessWidget {
  const AppResponsiveButtonPair({
    super.key,
    required this.start,
    this.end,
    this.spacing,
    this.breakpoint = AppMetrics.responsiveButtonPairBreakpoint,
  });

  final Widget start;
  final Widget? end;
  final double? spacing;

  /// Available width below which the pair stacks vertically.
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    final gap = spacing ?? AppSpacing.smMd;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackVertically =
            constraints.maxWidth < breakpoint || end == null;
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
