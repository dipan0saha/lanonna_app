import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/la_nonna_theme.dart';

/// Trailing control for [HomeSectionHeader] (compact, fixed row height).
sealed class HomeSectionTrailing {
  const HomeSectionTrailing();

  Widget build(BuildContext context);
}

/// Tappable “View all” style link on home section headers.
class HomeSectionLink extends HomeSectionTrailing {
  const HomeSectionLink({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Text(
          label,
          style: context.textStyles.labelSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Non-interactive status text (e.g. checklist progress).
class HomeSectionMeta extends HomeSectionTrailing {
  const HomeSectionMeta({
    required this.text,
    this.style,
  });

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        text,
        style: style ??
            context.textStyles.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
