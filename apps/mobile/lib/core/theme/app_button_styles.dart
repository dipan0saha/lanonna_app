import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Button variants layered on [AppTheme]'s `outlinedButtonTheme` /
/// `elevatedButtonTheme` (which supply size, padding, shape and typography).
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

  /// Error-filled primary CTA for irreversible deletes/removals
  /// (prototype `#confirmOverlay` danger button). Layer on [ElevatedButton].
  static final ButtonStyle primaryDestructive = ElevatedButton.styleFrom(
    backgroundColor: AppColors.error,
    foregroundColor: AppColors.surface,
  );
}
