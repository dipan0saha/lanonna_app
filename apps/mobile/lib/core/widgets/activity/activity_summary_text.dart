import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/la_nonna_theme.dart';

class ActivitySummaryText extends StatelessWidget {
  const ActivitySummaryText({
    super.key,
    required this.summary,
    this.actorDisplayName,
  });

  final String summary;
  final String? actorDisplayName;

  @override
  Widget build(BuildContext context) {
    final base = context.textStyles.bodySmall?.copyWith(
      fontSize: 12.5,
      height: 1.4,
      color: AppColors.textPrimary,
    );
    final actor = actorDisplayName?.trim();
    if (actor != null &&
        actor.isNotEmpty &&
        summary.startsWith(actor)) {
      final rest = summary.substring(actor.length);
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: actor, style: base?.copyWith(fontWeight: FontWeight.w700)),
            TextSpan(text: rest, style: base),
          ],
        ),
      );
    }
    return Text(summary, style: base);
  }
}
