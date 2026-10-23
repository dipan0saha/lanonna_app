# RCA: Follower lands on owner Announce Arrival form (BABY-003 / ONB-007)

## Summary

When a baby is marked born but owners have not published a keepsake announcement (`GET …/announcement` → 404), a **follower** who taps **View Announcement** on the birth welcome card is routed to the owner-only **Announce Arrival** create form instead of the empty “No announcement yet” state.

## Root causes

### 1. Unconditional redirect to create when fetch returns null

`AnnouncementCardScreen._load()` sets `_isOwner` from `routeBaby?.role == 'owner'` then, if `detail == null`, always `context.replace('…/announcement/create')` without checking ownership. The follower empty state in `build()` (`AppEmptyState` + `emptyAnnouncementYet`) is unreachable because navigation happens first.

### 2. Create route has no owner guard

`/baby/:babyId/announcement/create` builds `AnnouncementCreateScreen` for any member. Calendar and registry shipping already reject non-owners in-screen (`event_form_screen.dart`, `registry_shipping_address_screen.dart`).

### 3. Home CTA does not reflect announcement availability for followers

`HomeBirthWelcomeCard` always shows **View Announcement** for every role. `BirthWelcomeSummary.announcementId` is available from home-summary but unused, so followers see a button that implies content exists when it does not.

## Related code with the same flaw

| Location | Issue |
|----------|--------|
| `announcement_card_screen.dart` L67–68 | Redirect without `_isOwner` |
| `announcement_create_screen.dart` | No role check on load |
| `home_birth_welcome_card.dart` | View button always visible |

Owner home flow that pushes create after marking born (`home_screen.dart`) is correct — owners only.

## Fix direction

| Layer | Change |
|-------|--------|
| `announcement_card_screen.dart` | Redirect to create only when `_isOwner && detail == null` |
| `announcement_create_screen.dart` | On load, if `babyById` role ≠ owner: snackbar + pop (match event form) |
| `home_birth_welcome_card.dart` | Show **View Announcement** when owner **or** `announcementId != null` |
| Tests | Card screen: follower + null detail → empty state, not create; create screen: follower turned away |

## References

- GitHub #370, pre-prod plan BABY-003 / ONB-007
- `apps/mobile/lib/features/announcement/presentation/announcement_card_screen.dart`
- `apps/mobile/lib/features/home/presentation/widgets/home_birth_welcome_card.dart`
