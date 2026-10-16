# Mobile UI prototype parity

The Flutter app (`apps/mobile`) shares a single theme and widget library under `lib/core/theme` and `lib/core/widgets`. Feature screens should use those primitives instead of one-off colors or layouts.

## Shared building blocks

- **Empty states** — `AppEmptyState` (pale-green circle icon, dark title, optional CTA). Used on Gallery, Calendar, Registry, Fun, and Notifications inbox.
- **Registry** — `RegistryPriorityChip` (orange P1–P5), `AppGiftPillButton` for purchase CTAs, compact `RegistryNeededRow`.
- **Announcement** — `AnnouncementKeepsakeCard` (white card, Dancing Script first name, four stat icons, hand-icon squish pill). Used on the announcement screen and share image rendering.
- **Shell** — `HomeTopBar` via `shellHomeTopBar`: add baby (`+`), baby name with chevron (switcher), search, bell with unread dot (`NotificationsUnreadSignal`), account avatar.
- **Theme scale** — `AppSpacing` (4–24px rhythm) and extended `AppMetrics` for shell, keepsake, gallery badges, AI banners, calendar grid, predictions bars, and list rows. Prefer `context.calendarMonthTitleStyle`, `shellBabySwitcherTitleStyle`, and `accountProfileNameStyle` over literal font sizes.
- **AI banners** — `CalendarAiSuggestionBanner` (peach→sage gradient, white icon chip) on Calendar and Registry tabs.
- **Calendar** — Grouped upcoming events in `CalendarGroupedEventsCard`; caps **Upcoming** header with **Past** sheet (`past=true` on events API). Two-letter weekday headers and dark month title on the grid.
- **Registry** — `RegistrySortControl` + `sortRegistryItems` for needed items; shipping block uses `AppSectionCapsLabel` and bordered address card with **Edit** → existing shipping flow.
- **Account** — `AccountProfileCard` + `AccountTintedAvatar`; `AccountBabyProfilesCard` for baby rows.
- **Gallery** — `GalleryTileBadge` for squish/comment counts on grid tiles (API fields `squish_count`, `comment_count`).
- **Events** — `AppSectionCapsLabel`, `AppRsvpTileRow`, `AvatarStack` on event detail.
- **Home** — `HomeNextUpSection`, `TintedIconSquare` quick actions, `HomeBirthWelcomeCard` (born summary for owners and followers).

## Backend

- Home `birth_welcome` is returned for all members when the baby is born (not owner-only). Includes `birth_date`, `weight_text`, and `everyone_notified` (owners with an announcement).
- Calendar `GET .../events?past=true` returns up to 30 past events, newest first (for the Past bottom sheet).
- Baby gender `unknown` is supported on patch (Edit Baby “Not sure yet”).

## Verify

```bash
cd apps/mobile && flutter analyze && flutter test
cd services/api && pytest tests/test_home_summary.py
```
