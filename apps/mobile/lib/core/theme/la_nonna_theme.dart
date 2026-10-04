import 'package:flutter/material.dart';

import 'app_brand_theme.dart';

/// Access the single app theme from any widget under [MaterialApp].
extension LaNonnaTheme on BuildContext {
  ThemeData get laTheme => Theme.of(this);

  TextTheme get textStyles => Theme.of(this).textTheme;

  /// Label above text fields (onboarding and inputs); PRD §5.1 Inter semibold on surface.
  TextStyle get fieldLabelStyle => textStyles.labelMedium!.copyWith(
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      );

  ColorScheme get colors => Theme.of(this).colorScheme;

  AppBrandTheme get brand =>
      Theme.of(this).extension<AppBrandTheme>() ?? AppBrandTheme.light;
}
