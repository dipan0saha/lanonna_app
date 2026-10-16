import 'package:flutter/material.dart';

import 'app_brand_theme.dart';
import 'app_text_theme.dart';

export 'app_spacing.dart';

/// Access the single app theme from any widget under [MaterialApp].
extension LaNonnaTheme on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;

  /// Label above text fields (onboarding and inputs); PRD §5.1 Inter semibold on surface.
  TextStyle get fieldLabelStyle => textStyles.labelMedium!.copyWith(
    fontWeight: FontWeight.w600,
    color: colors.onSurface,
  );

  /// Typed text inside bordered fields (regular weight).
  TextStyle get fieldInputStyle => AppTextTheme.fieldInput(textStyles);

  ColorScheme get colors => Theme.of(this).colorScheme;

  AppBrandTheme get brand =>
      Theme.of(this).extension<AppBrandTheme>() ?? AppBrandTheme.light;

  /// Script font for keepsake announcement names.
  TextStyle get keepsakeScriptNameStyle =>
      AppTextTheme.keepsakeScriptName(textStyles);

  TextStyle get shellBabySwitcherTitleStyle =>
      AppTextTheme.shellBabySwitcherTitle(textStyles);

  TextStyle get accountProfileNameStyle =>
      AppTextTheme.accountProfileName(textStyles);

  TextStyle get calendarMonthTitleStyle =>
      AppTextTheme.calendarMonthTitle(textStyles);
}
