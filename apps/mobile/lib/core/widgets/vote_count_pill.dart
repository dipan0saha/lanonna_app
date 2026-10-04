import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/la_nonna_theme.dart';

/// Compact sage pill for gender vote totals (home insight + Fun predictions).
class VoteCountPill extends StatelessWidget {
  const VoteCountPill({super.key, required this.total});

  final int total;

  static String labelFor(int total) {
    if (total == 1) return '1 VOTE';
    return '$total VOTES';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.sageTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        labelFor(total),
        style: context.textStyles.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.03,
          color: AppColors.primaryDark,
          height: 1,
        ),
      ),
    );
  }
}
