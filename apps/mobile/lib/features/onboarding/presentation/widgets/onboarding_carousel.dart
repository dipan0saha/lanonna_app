import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';

class OnboardingCarousel extends StatefulWidget {
  const OnboardingCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.currentIndex,
    this.onPageChanged,
    this.controller,
    this.pageHeight = 360,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int currentIndex;
  final ValueChanged<int>? onPageChanged;
  final PageController? controller;
  final double pageHeight;

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
      children: [
        SizedBox(
          height: widget.pageHeight,
          child: PageView.builder(
            itemCount: widget.itemCount,
            controller: _controller,
            onPageChanged: widget.onPageChanged,
            itemBuilder: widget.itemBuilder,
          ),
        ),
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
