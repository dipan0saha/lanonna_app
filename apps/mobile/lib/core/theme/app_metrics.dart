import 'package:flutter/material.dart';

abstract final class AppMetrics {
  /// Onboarding pages and in-app sections (PRD §5.1).
  static const double horizontalPadding = 26;

  /// Stack subpages (account, settings, followers): single horizontal inset.
  static EdgeInsets get subpageScrollPadding =>
      const EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 24);

  /// Horizontal-only outer inset (tab sections, slivers, rows).
  static EdgeInsets get pageHorizontalInsets =>
      const EdgeInsets.symmetric(horizontal: horizontalPadding);

  /// Stack subpage forms with primary button at bottom (shipping, registry item).
  static EdgeInsets get subpageFormScrollPadding =>
      const EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 96);

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

  /// Onboarding optional choice pills (prototype `.pill-opt` / `.pill-select`).
  static const double choicePillGap = 10;
  static const double choicePillHorizontalPadding = 18;
  static const double choicePillVerticalPadding = 10;
  static const double choicePillMinHeight = 44;

  /// Toggle / badge / removable chips (prototype preset pills).
  static const double appChipHorizontalPadding = 13;
  static const double appChipVerticalPadding = 8;
  static const double appChipBorderWidth = 1.5;
  static const double appChipDenseVerticalPadding = 4;

  static const double surfaceRadius = 16;
  static const double surfacePadding = 18;
  static const double headlineSize = 24;
  static const double supportTextSize = 14.5;
  static const double dotSize = 7;
  static const double activeDotWidth = 20;
  static const double activeDotRadius = 8;

  /// Centred empty states (prototype `.empty-state`).
  static const double emptyStateIconCircle = 96;
  static const double emptyStateIconSize = 40;
  static const double emptyStateTitleGap = 20;
  static const double emptyStateMessageGap = 6;
  static const double emptyStateHorizontalInset = 30;

  /// Quick-action / list leading icon square (prototype `.quick-action .ic`).
  static const double tintedIconSquareSize = 34;
  static const double tintedIconSquareIconSize = 20;
  static const double tintedIconSquareRadius = 10;

  /// Compact solid pill CTA (registry gift button).
  static const double compactPillHorizontalPadding = 14;
  static const double compactPillVerticalPadding = 9;

  /// Selectable tile rows (RSVP Going / Maybe / Can't go).
  static const double selectTileRadius = fieldRadius;
  static const double selectTileVerticalPadding = 14;
}
