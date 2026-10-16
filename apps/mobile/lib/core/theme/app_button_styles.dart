import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Outlined button variants layered on [AppTheme]'s `outlinedButtonTheme`
/// (which supplies size, padding, shape and the neutral secondary look).
abstract final class AppButtonStyles {
  /// Green-outlined secondary CTA (prototype `.btn-outline-green`).
  static final ButtonStyle outlinedAccent = OutlinedButton.styleFrom(
    foregroundColor: AppColors.primaryDark,
    side: const BorderSide(color: AppColors.primaryDark),
  );

  /// Destructive outlined action (Log Out, Delete, Remove).
  static final ButtonStyle outlinedDestructive = OutlinedButton.styleFrom(
    foregroundColor: AppColors.error,
    side: const BorderSide(color: AppColors.error),
  );
}
