import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'onboarding_prototype_widgets.dart';

/// Decorative icon blob for owner carousel slides.
class OnboardingCarouselArt extends StatelessWidget {
  const OnboardingCarouselArt({
    super.key,
    required this.backgroundColor,
    required this.child,
  });

  final Color backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OnboardingIconBlob(
        backgroundColor: backgroundColor,
        child: child,
      ),
    );
  }
}

/// Static slide art presets (sage / peach tints per PRD).
abstract final class OnboardingCarouselSlideArt {
  static Widget homeIcon() => OnboardingCarouselArt(
        backgroundColor: AppColors.sageTint,
        child: Icon(
          Icons.home_outlined,
          size: 64,
          color: AppColors.primaryDark,
        ),
      );

  static Widget peopleIcon() => OnboardingCarouselArt(
        backgroundColor: AppColors.peachTint,
        child: Icon(
          Icons.people_outline,
          size: 64,
          color: AppColors.secondaryDark,
        ),
      );

  static Widget calendarIcon() => OnboardingCarouselArt(
        backgroundColor: AppColors.sageTint,
        child: Icon(
          Icons.calendar_month_outlined,
          size: 64,
          color: AppColors.primaryDark,
        ),
      );

  static Widget photoIcon() => OnboardingCarouselArt(
        backgroundColor: AppColors.peachTint,
        child: Icon(
          Icons.photo_library_outlined,
          size: 64,
          color: AppColors.secondaryDark,
        ),
      );
}
