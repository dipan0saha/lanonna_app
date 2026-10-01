import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/onboarding_routes.dart';
import '../../domain/onboarding_step.dart';
import '../onboarding_coordinator.dart';
import '../widgets/onboarding_buttons.dart';
import '../widgets/onboarding_carousel.dart';
import '../widgets/onboarding_carousel_art.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/onboarding_typography.dart';
import '../widgets/owner_carousel_slides.dart';

class OwnerCarouselScreen extends StatefulWidget {
  const OwnerCarouselScreen({super.key});

  @override
  State<OwnerCarouselScreen> createState() => _OwnerCarouselScreenState();
}

class _OwnerCarouselScreenState extends State<OwnerCarouselScreen> {
  static const _slideArt = [
    OnboardingCarouselSlideArt.homeIcon,
    OnboardingCarouselSlideArt.peopleIcon,
    OnboardingCarouselSlideArt.calendarIcon,
    OnboardingCarouselSlideArt.photoIcon,
  ];

  PageController? _pageController;
  int _index = 0;
  var _syncedStep = false;

  bool get _isLastSlide => _index == ownerCarouselSlideCount - 1;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_syncedStep) return;
    _syncedStep = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OnboardingCoordinator>().setStep(OnboardingStep.carousel);
    });
  }

  Future<void> _goToSignup() async {
    final coordinator = context.read<OnboardingCoordinator>();
    await coordinator.setStep(OnboardingStep.signup);
    if (!mounted) return;
    context.go(OnboardingRoutes.signup);
  }

  void _onPrimaryPressed() {
    if (!_isLastSlide) {
      _pageController?.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _goToSignup();
    }
  }

  @override
  Widget build(BuildContext context) {
    _pageController ??= PageController(initialPage: _index);

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _pageController?.previousPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      },
      child: OnboardingScaffold(
        showSkip: !_isLastSlide,
        onSkip: _goToSignup,
        bottom: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OnboardingPrimaryButton(
              buttonKey: _isLastSlide
                  ? const Key('owner_carousel_get_started')
                  : const Key('owner_carousel_next'),
              label: _isLastSlide ? 'Get started' : 'Next',
              onPressed: _onPrimaryPressed,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go(OnboardingRoutes.login),
              child: const Text('I already have an account'),
            ),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 8),
            OnboardingCarousel(
              itemCount: ownerCarouselSlideCount,
              currentIndex: _index,
              controller: _pageController,
              pageHeight: 420,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, index) {
                final slide = ownerCarouselSlide(index);
                return Column(
                  children: [
                    _slideArt[index](),
                    const SizedBox(height: 28),
                    OnboardingHeadline(slide.$1, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OnboardingSupportText(slide.$2, textAlign: TextAlign.center),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
