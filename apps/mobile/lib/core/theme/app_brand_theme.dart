import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Brand colors and fills not covered by [ColorScheme] (PRD §5.1).
///
/// Read via `context.brand` — do not duplicate these hex values in features.
@immutable
class AppBrandTheme extends ThemeExtension<AppBrandTheme> {
  const AppBrandTheme({
    required this.sageTint,
    required this.peachTint,
    required this.insightOnSageTint,
    required this.surfaceSubtle,
    required this.shellIconMuted,
    required this.ownerBadgeText,
    required this.fieldPlaceholder,
    required this.segmentUnselectedLabel,
  });

  final Color sageTint;
  final Color peachTint;
  final Color insightOnSageTint;
  final Color surfaceSubtle;
  final Color shellIconMuted;
  final Color ownerBadgeText;
  final Color fieldPlaceholder;
  final Color segmentUnselectedLabel;

  static const AppBrandTheme light = AppBrandTheme(
    sageTint: AppColors.sageTint,
    peachTint: AppColors.peachTint,
    insightOnSageTint: Color(0xFF3F5A37),
    surfaceSubtle: Color(0xFFF7F7F8),
    shellIconMuted: Color(0xFF6B6B6B),
    ownerBadgeText: Color(0xFF8A4A24),
    fieldPlaceholder: Color(0xFFB8B8BA),
    segmentUnselectedLabel: Color(0xFF8B8B8D),
  );

  @override
  AppBrandTheme copyWith({
    Color? sageTint,
    Color? peachTint,
    Color? insightOnSageTint,
    Color? surfaceSubtle,
    Color? shellIconMuted,
    Color? ownerBadgeText,
    Color? fieldPlaceholder,
    Color? segmentUnselectedLabel,
  }) {
    return AppBrandTheme(
      sageTint: sageTint ?? this.sageTint,
      peachTint: peachTint ?? this.peachTint,
      insightOnSageTint: insightOnSageTint ?? this.insightOnSageTint,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      shellIconMuted: shellIconMuted ?? this.shellIconMuted,
      ownerBadgeText: ownerBadgeText ?? this.ownerBadgeText,
      fieldPlaceholder: fieldPlaceholder ?? this.fieldPlaceholder,
      segmentUnselectedLabel:
          segmentUnselectedLabel ?? this.segmentUnselectedLabel,
    );
  }

  @override
  AppBrandTheme lerp(ThemeExtension<AppBrandTheme>? other, double t) {
    if (other is! AppBrandTheme) return this;
    return AppBrandTheme(
      sageTint: Color.lerp(sageTint, other.sageTint, t)!,
      peachTint: Color.lerp(peachTint, other.peachTint, t)!,
      insightOnSageTint: Color.lerp(insightOnSageTint, other.insightOnSageTint, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      shellIconMuted: Color.lerp(shellIconMuted, other.shellIconMuted, t)!,
      ownerBadgeText: Color.lerp(ownerBadgeText, other.ownerBadgeText, t)!,
      fieldPlaceholder: Color.lerp(fieldPlaceholder, other.fieldPlaceholder, t)!,
      segmentUnselectedLabel:
          Color.lerp(segmentUnselectedLabel, other.segmentUnselectedLabel, t)!,
    );
  }
}
