import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/onboarding/domain/baby_gender.dart';
import 'package:lanonna/features/onboarding/presentation/widgets/onboarding_fields.dart';
import 'package:lanonna/features/onboarding/presentation/widgets/onboarding_prototype_widgets.dart';

void main() {
  testWidgets('segmented control slides thumb when selection changes', (tester) async {
    var leftSelected = true;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return OnboardingSegmentedControl(
                leftLabel: 'Expecting',
                rightLabel: 'Already Born',
                isLeftSelected: leftSelected,
                onLeftTap: () => setState(() => leftSelected = true),
                onRightTap: () => setState(() => leftSelected = false),
              );
            },
          ),
        ),
      ),
    );

    final thumbFinder = find.byType(AnimatedPositioned);
    expect(thumbFinder, findsOneWidget);

    final left = tester.getTopLeft(thumbFinder);
    await tester.tap(find.text('Already Born'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final mid = tester.getTopLeft(thumbFinder);
    expect(mid.dx, greaterThan(left.dx));

    await tester.pumpAndSettle();
    final right = tester.getTopLeft(thumbFinder);
    expect(right.dx, greaterThan(left.dx));
  });

  testWidgets('mini style matches first-moment Boy/Girl toggle size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: OnboardingSegmentedControl(
            style: OnboardingSegmentedControlStyle.mini,
            leftLabel: 'Boy',
            rightLabel: 'Girl',
            isLeftSelected: true,
            onLeftTap: () {},
            onRightTap: () {},
          ),
        ),
      ),
    );

    final box = tester.getSize(find.byType(OnboardingSegmentedControl));
    expect(box.width, 140);
    expect(OnboardingSegmentedControlStyle.mini.segmentGap, 3);
  });

  testWidgets('PrototypeMiniGenderToggle slides thumb Boy to Girl', (tester) async {
    var selected = BabyGender.male;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return PrototypeMiniGenderToggle(
                selected: selected,
                onSelected: (g) => setState(() => selected = g),
              );
            },
          ),
        ),
      ),
    );

    final thumbFinder = find.byType(AnimatedPositioned);
    final left = tester.getTopLeft(thumbFinder);

    await tester.tap(find.byKey(const Key('prototype_mini_gender_girl')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(selected, BabyGender.female);
    expect(tester.getTopLeft(thumbFinder).dx, greaterThan(left.dx));

    await tester.tap(find.byKey(const Key('prototype_mini_gender_girl')));
    await tester.pump();
    expect(selected, BabyGender.female);
  });
}
