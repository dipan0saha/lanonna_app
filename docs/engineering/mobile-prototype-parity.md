# Mobile UI prototype parity

The Flutter app (`apps/mobile`) shares a single theme and widget library under `lib/core/theme` and `lib/core/widgets`. Feature screens should use those primitives instead of one-off colors or layouts.

**Reference:** [`docs/prototype/nonna_combined_prototype.html`](../prototype/nonna_combined_prototype.html) is the current UI prototype (older files are under `docs/prototype/Archive/`). Parity work (PRs #317–#321, Oct 2026) stayed inside the existing architecture: when a style changes, change the shared token or widget so every screen picks it up, and delete the duplicate it replaces.

**Rules:** no literal paddings, gaps, radii or font sizes in feature code — use `AppSpacing`, `AppMetrics`, and theme text styles; no raw `showModalBottomSheet`; no per-screen `OutlinedButton.styleFrom`; all copy in ARB ([development.md](development.md) → Localization).

## Shared building blocks

- **Empty states** — `AppEmptyState` (pale-green circle icon, dark title, optional CTA). Used on Gallery (including filtered modes), Calendar (FAB clearance), Registry, Fun names tab, and Notifications inbox.
- **Sheets** — every bottom sheet goes through `app_modal_sheet.dart`: `showAppModalSheet` (handle via `AppSheetHandle`, title, optional subtitle, **Close**, keyboard-safe flexible body) or `presentAppModalSheet` when the body builds its own `AppModalSheet` (stateful bodies). Used by RSVPs, Who voted, Past events, baby switcher, photo source, announce arrival, upload caption, and event cover picker.
- **Buttons** — `AppButtonLabel` (word-safe wraps), `AppResponsiveButtonPair` (stacks below 360dp), `AppGiftPillButton` (labels wrap at 360dp via `Flexible`), `AppCancelTextButton`, `AppSquishEngagementPill` / `AppEngagementPill`. Secondary buttons use the theme's single `outlinedButtonTheme`; variants are `AppButtonStyles.outlinedAccent` and `AppButtonStyles.outlinedDestructive`.
- **Shell / account** — `BabyProfileAvatar`, `MembershipRolePill`, `AppUnreadDot` (orange accent).
- **Registry** — `RegistryPriorityChip` (orange P1–P5), `AppGiftPillButton` for purchase CTAs, compact `RegistryNeededRow`.
- **Announcement** — `AnnouncementKeepsakeCard` (white card, Dancing Script first name, four stat icons, hand-icon squish pill). Used on the announcement screen and share image rendering.
- **Shell** — `HomeTopBar` via `shellHomeTopBar`: add baby (`+`), invite family (`group_add_outlined`), baby name with chevron (switcher), bell with unread dot (listens to `NotificationsRepository`, a `ChangeNotifier`), account avatar (loaded once via `AccountRepository.ensureAccountLoaded`).
- **Theme scale** — `AppSpacing` (2–24px: `hairline`, `xxs`…`xxl`, incl. `smMd` 10) and extended `AppMetrics` for shell, keepsake, gallery badges, AI banners, calendar grid, predictions bars, and list rows. Prefer `context.calendarMonthTitleStyle`, `shellBabySwitcherTitleStyle`, and `accountProfileNameStyle` over literal font sizes.
- **AI banners** — `CalendarAiSuggestionBanner` (peach→sage gradient, white icon chip) on Calendar and Registry tabs.
- **Calendar** — Grouped upcoming events in `CalendarGroupedEventsCard`; caps **Upcoming** header with **Past** sheet (`past=true` on events API). Two-letter weekday headers and dark month title on the grid.
- **Registry** — `RegistrySortControl` + `sortRegistryItems` for needed items; shipping block uses `AppSectionCapsLabel` and bordered address card with **Edit** → existing shipping flow.
- **Account** — `AccountProfileCard` + `AccountTintedAvatar`; `AccountBabyProfilesCard` for baby rows.
- **Gallery** — `GalleryTileBadge` for squish/comment counts on grid tiles (API fields `squish_count`, `comment_count`).
- **Events** — `AppSectionCapsLabel`, `AppRsvpTileRow`, `AvatarStack` on event detail.
- **Home** — `HomeNextUpSection`, `TintedIconSquare` quick actions, `HomeBirthWelcomeCard` (born summary for owners and followers; share reuses `AnnouncementShare`).
- **Notifications inbox** — two-line rows with a `TintedIconSquare` icon chosen from the server `notification_type`, an ARB sentence built from `notification_kind` + `params` with the actor in bold, `AppUnreadDot`, and **Mark all read**.
- **Fun after birth** — Names and Predictions stay visible with a compact read-only note (`namesClosedNote` / `predictionsClosedNote`), driven by server `names_closed` / `predictions_closed`.
- **Copy helpers** — `babyDisplayName` (never prefixes the baby name), `personDisplayName`, `PlaceholderRichText` (localized sentences with styled placeholders: tappable terms links, bold names in activity and inbox rows).
- **Tab reload** — tabs mix in `BabyContextReload` (baby switch + reconnect) and `TabLoadGenerationCache`; paginated lists refresh with `refreshPaginatedWindow`.

## Backend

- Home `birth_welcome` is returned for all members when the baby is born (not owner-only). Includes `birth_date`, `weight_text`, and `everyone_notified` (owners with an announcement).
- Calendar `GET .../events?past=true` returns an offset page (default 30, max 100), newest first; the Past bottom sheet loads more pages.
- Gallery grid badges use `squish_count` / `comment_count` on photo list rows.
- Name suggestions and likes after birth return **409** `fun_closed` (predictions: `predictions_closed`).
- Baby gender `unknown` is supported on patch (Edit Baby “Not sure yet”).

## Verify

```bash
cd apps/mobile && flutter analyze && flutter test && dart run tool/check_hardcoded_user_strings.dart .
cd services/api && pytest tests/test_home_summary.py
```
