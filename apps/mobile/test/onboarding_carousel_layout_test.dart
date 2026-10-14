import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/onboarding/presentation/widgets/onboarding_carousel.dart';
import 'package:lanonna/features/onboarding/presentation/widgets/onboarding_carousel_caption.dart';
import 'package:lanonna/features/onboarding/presentation/widgets/onboarding_prototype_widgets.dart';

void main() {
  Future<void> pumpCarousel(
    WidgetTester tester, {
    double? artPageHeight,
    double totalHeight = 640,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            height: totalHeight,
            width: 400,
            child: Column(
              children: [
                Expanded(
                  child: OnboardingCarousel(
                    itemCount: 1,
                    currentIndex: 0,
                    artPageHeight: artPageHeight,
                    artBuilder: (context, index) => const OnboardingIconBlob(
                      size: 120,
                      backgroundColor: Color(0xFFE8F0E8),
                      child: Icon(Icons.home_outlined),
                    ),
                    captionBuilder: (context, index) =>
                        const OnboardingCarouselCaption(
                      title: 'Title',
                      body: 'Body copy',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('carousel caption sits below centered art region', (tester) async {
    await pumpCarousel(tester, artPageHeight: 260);

    final artCenter = tester.getCenter(find.byType(OnboardingIconBlob));
    final titleTop = tester.getTopLeft(find.text('Title'));
    expect(
      titleTop.dy,
      greaterThan(artCenter.dy),
      reason: 'copy should render below the art blob',
    );
  });

  testWidgets('expanded art region centers icon above caption band', (tester) async {
    await pumpCarousel(tester);

    final artCenter = tester.getCenter(find.byType(OnboardingIconBlob));
    final titleTop = tester.getTopLeft(find.text('Title')).dy;
    final bandMid = titleTop / 2;
    expect(
      artCenter.dy,
      closeTo(bandMid, 40),
      reason: 'icon should sit mid-way in whitespace above headline',
    );
  });
}
