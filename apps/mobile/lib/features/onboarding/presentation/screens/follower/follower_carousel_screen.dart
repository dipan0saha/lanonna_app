import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/onboarding_step.dart';
import '../../onboarding_coordinator.dart';
import '../../utils/invite_flow_navigation.dart';
import '../../widgets/onboarding_buttons.dart';
import '../../widgets/onboarding_carousel.dart';
import '../../widgets/onboarding_carousel_art.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/onboarding_typography.dart';

class FollowerCarouselScreen extends StatefulWidget {
  const FollowerCarouselScreen({super.key});

  @override
  State<FollowerCarouselScreen> createState() => _FollowerCarouselScreenState();
}

class _FollowerCarouselScreenState extends State<FollowerCarouselScreen> {
  PageController? _pageController;
  var _index = 0;
  var _synced = false;

  List<(String title, String body, Widget Function() art)> _slidesFor(bool isBorn) {
    final branch = isBorn
        ? (
            'Relive every milestone in the Gallery',
            'Baby is already here. See the first photos and everything since.',
            OnboardingCarouselSlideArt.photoIcon,
          )
        : (
            'Vote & guess in Family Fun',
            'Suggest names, vote on favorites, and guess the birthdate. Results reveal once baby arrives.',
            OnboardingCarouselSlideArt.homeIcon,
          );

    return [
      (
        "Welcome, you're in!",
        'A private space just for the family and friends closest to your circle.',
        OnboardingCarouselSlideArt.homeIcon,
      ),
      (
        'Squish photos & leave comments',
        'Tap the heart to "squish" any photo the family shares.',
        OnboardingCarouselSlideArt.peopleIcon,
      ),
      (
        'Never miss what\'s next',
        'See upcoming events, like gender reveals and baby showers, and RSVP right from the app.',
        OnboardingCarouselSlideArt.calendarIcon,
      ),
      branch,
      (
        'Get updates your way',
        'Choose how often you hear from us: real-time, daily, or a weekly digest. You can change this anytime.',
        OnboardingCarouselSlideArt.calendarIcon,
      ),
    ];
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_synced) return;
    _synced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OnboardingCoordinator>().setStep(OnboardingStep.followerCarousel);
    });
  }

  Future<void> _finish() => finishInviteOnboardingAndGoHome(context);

  @override
  Widget build(BuildContext context) {
    final isBorn =
        context.watch<OnboardingCoordinator>().cachedInvitePreview?.isBorn ?? false;
    final slides = _slidesFor(isBorn);
    final isLast = _index == slides.length - 1;
    _pageController ??= PageController(initialPage: _index);

    return OnboardingScaffold(
      showSkip: !isLast,
      onSkip: _finish,
      pinBottomCta: false,
      bottom: OnboardingPrimaryButton(
        label: isLast ? 'Get Started' : 'Next',
        onPressed: () {
          if (!isLast) {
            _pageController?.nextPage(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
            return;
          }
          _finish();
        },
      ),
      body: OnboardingCarousel(
        itemCount: slides.length,
        currentIndex: _index,
        controller: _pageController,
        pageHeight: 420,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, index) {
          final slide = slides[index];
          return Column(
            children: [
              slide.$3(),
              const SizedBox(height: 28),
              OnboardingHeadline(slide.$1, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OnboardingSupportText(slide.$2, textAlign: TextAlign.center),
            ],
          );
        },
      ),
    );
  }
}
