import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_colors.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/onboarding/presentation/widgets/onboarding_prototype_widgets.dart';

void main() {
  Future<void> pumpBlob(WidgetTester tester, {double size = 120}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: OnboardingIconBlob(
              size: size,
              backgroundColor: AppColors.sageTint,
              child: Icon(
                Icons.home_outlined,
                size: size * 0.36,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration blobDecoration(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(OnboardingIconBlob),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration;
    expect(decoration, isA<BoxDecoration>());
    return decoration! as BoxDecoration;
  }

  testWidgets('OnboardingIconBlob uses a circle backdrop at the requested size',
      (tester) async {
    const size = 120.0;
    await pumpBlob(tester, size: size);

    final box = tester.getSize(find.byType(OnboardingIconBlob));
    expect(box.width, size);
    expect(box.height, size);

    final decoration = blobDecoration(tester);
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, AppColors.sageTint);
    expect(decoration.borderRadius, isNull);
  });

  testWidgets('OnboardingIconBlob matches golden', (tester) async {
    await pumpBlob(tester, size: 140);
    await expectLater(
      find.byType(OnboardingIconBlob),
      matchesGoldenFile('goldens/onboarding_icon_blob.png'),
    );
  });
}
