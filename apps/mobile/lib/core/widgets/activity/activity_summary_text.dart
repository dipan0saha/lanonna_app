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
      height: 1.4,
      color: AppColors.textPrimary,
    );
    // The server writes the copy and the actor name from the same user record,
    // so a structured actor is bolded only where the copy names it. Copy that
    // does not name the actor (e.g. "New event: …") renders as-is.
    final actor = actorDisplayName?.trim();
    if (actor != null && actor.isNotEmpty && summary.startsWith(actor)) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: actor,
              style: base?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: summary.substring(actor.length), style: base),
          ],
        ),
      );
    }
    return Text(summary, style: base);
  }
}
