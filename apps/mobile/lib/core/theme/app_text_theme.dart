import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_metrics.dart';

/// Canonical text styles for the app (PRD §5.1). Wired into [AppTheme.light].
abstract final class AppTextTheme {
  static TextTheme build() {
    return TextTheme(
      displayLarge: GoogleFonts.baloo2(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        color: AppColors.secondaryDark,
        height: 1,
      ),
      headlineLarge: GoogleFonts.baloo2(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.primaryDark,
      ),
      headlineMedium: GoogleFonts.baloo2(
        fontSize: AppMetrics.headlineSize,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.15,
      ),
      titleLarge: GoogleFonts.baloo2(
        fontSize: AppMetrics.headlineSize,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.baloo2(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryDark,
      ),
      titleSmall: GoogleFonts.baloo2(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: AppMetrics.supportTextSize,
        color: AppColors.muted,
        height: 1.45,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12.5,
        height: 1.5,
        color: AppColors.textPrimary,
      ),
      // Label roles (PRD §5.1):
      // - labelLarge: CTA on sage (filled primary buttons)
      // - labelMedium: on-surface emphasis (meta, counts, form labels via fieldLabelStyle)
      // - labelSmall: muted section caps / helper
      // Labels on filled accents use labelLarge or onPrimary — not labelMedium.
      labelLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.primaryButtonForeground,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.07 * 11,
        color: AppColors.muted,
      ),
    );
  }

  /// Typed user input inside bordered fields (not labels or hints).
  static TextStyle fieldInput(TextTheme textTheme) {
    return textTheme.bodyMedium!.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w400,
    );
  }
}
