import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_colors.dart';
import 'package:lanonna/core/theme/app_text_theme.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/theme/la_nonna_theme.dart';

void main() {
  testWidgets('labelMedium and fieldLabelStyle use on-surface primary text', (tester) async {
    late Color? labelMediumColor;
    late TextStyle fieldLabel;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            labelMediumColor = context.textStyles.labelMedium?.color;
            fieldLabel = context.fieldLabelStyle;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(labelMediumColor, AppColors.textPrimary);
    expect(fieldLabel.fontWeight, FontWeight.w600);
    expect(fieldLabel.color, AppColors.textPrimary);
  });

  test('headlineSmall uses Baloo display sizing for tab titles', () {
    final theme = AppTextTheme.build();
    final style = theme.headlineSmall!;
    expect(style.fontSize, 24);
    expect(style.fontWeight, FontWeight.w700);
    expect(style.color, AppColors.textPrimary);
    expect(style.height, 1.25);
  });

  test('fieldInput uses regular weight for typed text', () {
    final theme = AppTextTheme.build();
    final input = AppTextTheme.fieldInput(theme);
    expect(input.fontWeight, FontWeight.w400);
    expect(input.color, AppColors.textPrimary);
  });
}
