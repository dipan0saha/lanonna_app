import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';

/// Paged carousel: art in [PageView], copy below art (index-synced), then dots.
class OnboardingCarousel extends StatefulWidget {
  const OnboardingCarousel({
    super.key,
    required this.itemCount,
    required this.artBuilder,
    required this.captionBuilder,
    required this.currentIndex,
    this.onPageChanged,
    this.controller,
    this.artPageHeight = 280,
    this.captionGap = 20,
  });

  final int itemCount;
  final IndexedWidgetBuilder artBuilder;
  final Widget Function(BuildContext context, int index) captionBuilder;
  final int currentIndex;
  final ValueChanged<int>? onPageChanged;
  final PageController? controller;
  /// Height of the swipeable art region (icon centered vertically).
  final double artPageHeight;
  final double captionGap;

  @override
  State<OnboardingCarousel> createState() => _OnboardingCarouselState();
}

class _OnboardingCarouselState extends State<OnboardingCarousel> {
  PageController? _internalController;

  PageController get _controller =>
      widget.controller ??
      (_internalController ??=
          PageController(initialPage: widget.currentIndex));

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.artPageHeight,
          child: PageView.builder(
            itemCount: widget.itemCount,
            controller: _controller,
            onPageChanged: widget.onPageChanged,
            itemBuilder: (context, index) {
              return Center(child: widget.artBuilder(context, index));
            },
          ),
        ),
        SizedBox(height: widget.captionGap),
        widget.captionBuilder(context, widget.currentIndex),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.itemCount, (index) {
            final isActive = index == widget.currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? AppMetrics.activeDotWidth : AppMetrics.dotSize,
              height: AppMetrics.dotSize,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primaryDark : AppColors.border,
                borderRadius: BorderRadius.circular(
                  isActive
                      ? AppMetrics.activeDotRadius
                      : AppMetrics.dotSize / 2,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
