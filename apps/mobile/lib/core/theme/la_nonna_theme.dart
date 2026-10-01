import 'package:flutter/material.dart';

import 'app_brand_theme.dart';

/// Access the single app theme from any widget under [MaterialApp].
extension LaNonnaTheme on BuildContext {
  ThemeData get laTheme => Theme.of(this);

  TextTheme get textStyles => Theme.of(this).textTheme;

  ColorScheme get colors => Theme.of(this).colorScheme;

  AppBrandTheme get brand =>
      Theme.of(this).extension<AppBrandTheme>() ?? AppBrandTheme.light;
}
