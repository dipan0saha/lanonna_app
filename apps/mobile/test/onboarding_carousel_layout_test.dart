import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/onboarding/presentation/widgets/onboarding_carousel.dart';
import 'package:lanonna/features/onboarding/presentation/widgets/onboarding_carousel_caption.dart';
import 'package:lanonna/features/onboarding/presentation/widgets/onboarding_prototype_widgets.dart';

void main() {
  testWidgets('carousel caption sits below centered art region', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            height: 640,
            width: 400,
            child: OnboardingCarousel(
              itemCount: 1,
              currentIndex: 0,
              artPageHeight: 260,
              artBuilder: (context, index) => const OnboardingIconBlob(
                size: 120,
                backgroundColor: Color(0xFFE8F0E8),
                child: Icon(Icons.home_outlined),
              ),
              captionBuilder: (context, index) => const OnboardingCarouselCaption(
                title: 'Title',
                body: 'Body copy',
              ),
            ),
          ),
        ),
      ),
    );

    final artCenter = tester.getCenter(find.byType(OnboardingIconBlob));
    final titleTop = tester.getTopLeft(find.text('Title'));
    expect(
      titleTop.dy,
      greaterThan(artCenter.dy),
      reason: 'copy should render below the art blob',
    );
  });
}
