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
  static const double buttonMinWidth = 88;
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

  /// Shell top bar (prototype `.baby-switcher-btn`).
  static const double shellTopBarTopInset = 2;
  static const double shellTopBarBottomInset = 14;
  static const double shellBabySwitcherTitleSize = 17;
  static const double shellIconSize = 20;
  static const double shellAddIconSize = 22;
  static const double shellAccountAvatarSize = 34;
  static const double shellUnreadDotSize = 8;
  static const double shellUnreadDotBorderWidth = 1.5;

  /// Account profile header avatar (prototype account-main).
  static const double accountProfileAvatarRadius = 40;

  /// Announcement keepsake card.
  static const double keepsakeCardRadius = homeHeroRadius;
  static const double keepsakeCardMaxWidth = 360;
  static const double keepsakePhotoSize = 120;
  static const double keepsakePhotoBorderWidth = 3;
  static const double keepsakePhotoShadowBlur = 12;
  static const double keepsakeCardShadowBlur = 28;
  static const double keepsakeCardShadowYOffset = 10;
  static const EdgeInsets keepsakeCardPadding = EdgeInsets.fromLTRB(
    24,
    28,
    24,
    22,
  );
  static const double keepsakeScriptNameSize = 36;
  static const double keepsakeLastNameLetterSpacing = 2.4;
  static const double keepsakeStatColumnWidth = 120;
  static const double keepsakeStatIconSize = shellIconSize;
  static const double keepsakePlaceholderAvatarRadius = 52;
  static const double keepsakePlaceholderChildIconSize = 40;
  static const double keepsakeEngagementIconSize = 16;

  /// Gallery grid tile badges and layout.
  static const double galleryGridSpacing = 6;
  static const double galleryTileRadius = fieldRadius;
  static const double galleryTileBadgeRadius = 8;
  static const EdgeInsets galleryTileBadgePadding = EdgeInsets.symmetric(
    horizontal: 6,
    vertical: 2,
  );

  /// AI suggestion banners (calendar + registry tabs).
  static const double aiBannerRadius = fieldRadius;
  static const EdgeInsets aiBannerPadding = EdgeInsets.all(14);
  static const double aiBannerIconChipSize = tintedIconSquareSize;

  /// Calendar month grid weekday headers (two-letter).
  static const double calendarDayCellRadius = 10;
  static const double calendarEventDotSize = 6;

  /// Popular dates progress bars (Fun predictions).
  static const double predictionBarHeight = 8;
  static const double predictionBarRadius = 4;

  /// Follower / member list leading emoji tile.
  static const double memberLeadingEmojiSize = 22;

  /// Bordered list rows (followers, registry cards).
  static const EdgeInsets borderedListRowPadding = aiBannerPadding;
  static const double listRowBottomGap = 10;
  static const EdgeInsets monthGridCardPadding = EdgeInsets.all(12);

  /// Registry sort control tap target inset.
  static const EdgeInsets sortControlPadding = EdgeInsets.symmetric(
    horizontal: 4,
    vertical: 2,
  );

  /// Modal bottom-sheet grab handle.
  static const double sheetHandleWidth = 36;
  static const double sheetHandleHeight = 4;

  /// Stack paired CTAs vertically below this width (e.g. 360dp phones).
  static const double responsiveButtonPairBreakpoint = 360;

  /// Bottom scroll padding so empty states clear shell FABs.
  static const double fabScrollClearance = 96;

  /// Inline action / trailing icons in rows and compact controls.
  static const double inlineIconSize = 18;
  static const double trailingIconSize = 20;

  /// Next Up date block width (prototype `.next-up .date`).
  static const double nextUpDateBlockWidth = 48;

  /// Max height of an image preview inside a bottom sheet.
  static const double sheetImagePreviewMaxHeight = 200;

  /// Floating prev/next control over the photo hero (prototype `.photo-nav-hint`).
  static const double photoNavButtonElevation = 2;
}
