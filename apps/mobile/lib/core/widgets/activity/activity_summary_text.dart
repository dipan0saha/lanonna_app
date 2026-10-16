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

  int? _leadingActorLength(String text, String actor) {
    if (actor.isEmpty || text.isEmpty) return null;
    if (text.startsWith(actor)) return actor.length;
    final textLower = text.toLowerCase();
    final actorLower = actor.toLowerCase();
    if (textLower.startsWith(actorLower)) {
      return actor.length;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final base = context.textStyles.bodySmall?.copyWith(
      height: 1.4,
      color: AppColors.textPrimary,
    );
    final actor = actorDisplayName?.trim();
    if (actor != null && actor.isNotEmpty) {
      final prefixLength = _leadingActorLength(summary, actor);
      if (prefixLength != null) {
        final actorText = summary.substring(0, prefixLength);
        final rest = summary.substring(prefixLength);
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: actorText,
                style: base?.copyWith(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: rest, style: base),
            ],
          ),
        );
      }
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$actor ',
              style: base?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: summary, style: base),
          ],
        ),
      );
    }
    return Text(summary, style: base);
  }
}
