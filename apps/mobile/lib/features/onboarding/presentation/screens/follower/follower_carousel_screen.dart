import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../domain/onboarding_step.dart';
import '../../onboarding_coordinator.dart';
import '../../utils/invite_flow_navigation.dart';
import '../../widgets/onboarding_buttons.dart';
import '../../widgets/onboarding_carousel.dart';
import '../../widgets/onboarding_carousel_art.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/onboarding_carousel_caption.dart';

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
            AppLocalizations.of(context)!.onboardingReliveEveryMilestoneInThe,
            AppLocalizations.of(context)!.onboardingBabyIsAlreadyHereSee,
            OnboardingCarouselSlideArt.photoIcon,
          )
        : (
            AppLocalizations.of(context)!.onboardingVoteGuessInFamilyFun,
            AppLocalizations.of(context)!.onboardingSuggestNamesVoteOnFavorites,
            OnboardingCarouselSlideArt.homeIcon,
          );

    return [
      (
        AppLocalizations.of(context)!.onboardingWelcomeYoureIn,
        AppLocalizations.of(context)!.onboardingAPrivateSpaceJustFor,
        OnboardingCarouselSlideArt.homeIcon,
      ),
      (
        AppLocalizations.of(context)!.onboardingSquishPhotosLeaveComments,
        AppLocalizations.of(context)!.onboardingTapTheHeartToSquish,
        OnboardingCarouselSlideArt.peopleIcon,
      ),
      (
        AppLocalizations.of(context)!.onboardingNeverMissWhatsNext,
        AppLocalizations.of(context)!.onboardingSeeUpcomingEventsLikeGender,
        OnboardingCarouselSlideArt.calendarIcon,
      ),
      branch,
      (
        AppLocalizations.of(context)!.onboardingGetUpdatesYourWay,
        AppLocalizations.of(context)!.onboardingChooseHowOftenYouHear,
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
      scrollBody: false,
      showSkip: !isLast,
      onSkip: _finish,
      bottom: OnboardingPrimaryButton(
        label: isLast ? AppLocalizations.of(context)!.onboardingFollowerGetStarted : AppLocalizations.of(context)!.onboardingNext,
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
      body: Column(
        children: [
          Expanded(
            child: OnboardingCarousel(
            itemCount: slides.length,
            currentIndex: _index,
            controller: _pageController,
            onPageChanged: (i) => setState(() => _index = i),
            artBuilder: (context, index) => slides[index].$3(),
            captionBuilder: (context, index) {
              final slide = slides[index];
              return OnboardingCarouselCaption(
                title: slide.$1,
                body: slide.$2,
              );
            },
          ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
