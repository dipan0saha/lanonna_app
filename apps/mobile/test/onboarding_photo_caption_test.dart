import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/onboarding/presentation/widgets/onboarding_prototype_widgets.dart';

void main() {
  testWidgets('shows Add a photo when hasPhoto is false', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: OnboardingPhotoCaption(hasPhoto: false),
        ),
      ),
    );
    expect(find.text('Add a photo'), findsOneWidget);
    expect(find.text('Change photo'), findsNothing);
  });

  testWidgets('shows Change photo when hasPhoto is true', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: OnboardingPhotoCaption(hasPhoto: true),
        ),
      ),
    );
    expect(find.text('Change photo'), findsOneWidget);
  });

  testWidgets('tap invokes onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: OnboardingPhotoCaption(
            hasPhoto: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add a photo'));
    expect(tapped, isTrue);
  });
}
