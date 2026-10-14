import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';

/// Paged carousel: art in [PageView] (fills space above copy), caption, then dots.
///
/// Parent must give a bounded height (e.g. [Expanded] in the scaffold body).
class OnboardingCarousel extends StatefulWidget {
  const OnboardingCarousel({
    super.key,
    required this.itemCount,
    required this.artBuilder,
    required this.captionBuilder,
    required this.currentIndex,
    this.onPageChanged,
    this.controller,
    this.captionGap = 20,
    this.artPageHeight,
  });

  final int itemCount;
  final IndexedWidgetBuilder artBuilder;
  final Widget Function(BuildContext context, int index) captionBuilder;
  final int currentIndex;
  final ValueChanged<int>? onPageChanged;
  final PageController? controller;
  final double captionGap;
  /// When set, art uses a fixed height (tests). When null, art [Expanded] fills space above caption.
  final double? artPageHeight;

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

  Widget _artPageView() {
    return PageView.builder(
      itemCount: widget.itemCount,
      controller: _controller,
      onPageChanged: widget.onPageChanged,
      itemBuilder: (context, index) {
        return Center(child: widget.artBuilder(context, index));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final artHeight = widget.artPageHeight;
    final artRegion = artHeight != null
        ? SizedBox(height: artHeight, child: _artPageView())
        : Expanded(child: _artPageView());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        artRegion,
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
