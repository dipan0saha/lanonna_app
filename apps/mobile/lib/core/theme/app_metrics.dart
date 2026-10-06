import 'package:flutter/material.dart';

abstract final class AppMetrics {
  /// Onboarding pages and in-app sections (PRD §5.1).
  static const double horizontalPadding = 26;

  /// Stack subpages (account, settings, followers): single horizontal inset.
  static EdgeInsets get subpageScrollPadding => const EdgeInsets.fromLTRB(
        horizontalPadding,
        16,
        horizontalPadding,
        24,
      );

  /// Home hero / welcome cards (prototype shell).
  static const double homeHeroRadius = 20;
  static const double fieldRadius = 12;
  /// Gap between block section title and content below (cards, surfaces, lists).
  static const double sectionTitleGap = 10;

  /// Vertical space between major sections on the same scroll.
  static const double sectionBlockSpacing = 16;

  /// Fixed height for home [HomeSectionHeader] title row (title + trailing).
  static const double sectionHeaderRowHeight = 24;

  /// Gap between field label and input (prototype `.field-label`).
  static const double fieldLabelGap = 6;
  /// Vertical space between stacked form fields (prototype `.field` margin).
  static const double formFieldSpacing = 16;
  static const double fieldContentPaddingHorizontal = 16;
  static const double fieldContentPaddingVertical = 13;
  static const double buttonRadius = 999;
  static const double buttonMinHeight = 52;
  static const double buttonHorizontalPadding = 24;
  static const double buttonVerticalPadding = 15;
  static const double surfaceRadius = 16;
  static const double surfacePadding = 18;
  static const double headlineSize = 24;
  static const double supportTextSize = 14.5;
  static const double dotSize = 7;
  static const double activeDotWidth = 20;
  static const double activeDotRadius = 8;
}
