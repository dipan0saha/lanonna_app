# Mobile UI prototype parity

The Flutter app (`apps/mobile`) shares a single theme and widget library under `lib/core/theme` and `lib/core/widgets`. Feature screens should use those primitives instead of one-off colors or layouts.

## Shared building blocks

- **Empty states** — `AppEmptyState` (pale-green circle icon, dark title, optional CTA). Used on Gallery, Calendar, Registry, Fun, and Notifications inbox.
- **Registry** — `RegistryPriorityChip` (orange P1–P5), `AppGiftPillButton` for purchase CTAs, compact `RegistryNeededRow`.
- **Announcement** — `AnnouncementKeepsakeCard` (white card, Dancing Script first name, four stat icons, hand-icon squish pill). Used on the announcement screen and share image rendering.
- **Shell** — `HomeTopBar` via `shellHomeTopBar`: add baby (`+`), baby name with chevron (switcher), search, bell with unread dot (`NotificationsUnreadSignal`), account avatar.
- **Events** — `AppSectionCapsLabel`, `AppRsvpTileRow`, `AvatarStack` on event detail.
- **Home** — `HomeNextUpSection`, `TintedIconSquare` quick actions, `HomeBirthWelcomeCard` (born summary for owners and followers).

## Backend

- Home `birth_welcome` is returned for all members when the baby is born (not owner-only). Includes `birth_date`, `weight_text`, and `everyone_notified` (owners with an announcement).
- Baby gender `unknown` is supported on patch (Edit Baby “Not sure yet”).

## Verify

```bash
cd apps/mobile && flutter analyze && flutter test
cd services/api && pytest tests/test_home_summary.py
```
