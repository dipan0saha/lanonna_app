import 'package:flutter/material.dart';

import '../../../../core/theme/app_metrics.dart';
import '../../../../core/widgets/app_bordered_surface.dart';
import 'home_section_header.dart';
import 'home_section_trailing.dart';

/// Home scroll block: section header + body + optional tail spacing.
class HomeScrollSection extends StatelessWidget {
  const HomeScrollSection({
    super.key,
    required this.title,
    this.trailing,
    required this.body,
    this.sectionSpacingAfter = true,
  });

  final String title;
  final HomeSectionTrailing? trailing;
  final Widget body;
  final bool sectionSpacingAfter;

  /// Header + bordered surface with standard home inset and padding.
  factory HomeScrollSection.bordered({
    Key? key,
    required String title,
    HomeSectionTrailing? trailing,
    required Widget child,
    bool sectionSpacingAfter = true,
    EdgeInsetsGeometry? padding,
  }) {
    return HomeScrollSection(
      key: key,
      title: title,
      trailing: trailing,
      sectionSpacingAfter: sectionSpacingAfter,
      body: AppBorderedSurface(
        margin: EdgeInsets.symmetric(horizontal: AppMetrics.horizontalPadding),
        padding: padding ?? const EdgeInsets.all(AppMetrics.surfacePadding),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(title: title, trailing: trailing),
        body,
        if (sectionSpacingAfter)
          const SizedBox(height: AppMetrics.sectionBlockSpacing),
      ],
    );
  }
}
