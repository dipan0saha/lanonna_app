# RCA: Follower lands on owner Announce Arrival form (BABY-003 / ONB-007)

## Summary

When a baby is marked born but owners have not published a keepsake announcement (`GET …/announcement` → 404), a **follower** who taps **View Announcement** on the birth welcome card is routed to the owner-only **Announce Arrival** create form instead of the empty “No announcement yet” state.

## Root causes

### 1. Unconditional redirect to create when fetch returns null

`AnnouncementCardScreen._load()` sets `_isOwner` from `routeBaby?.role == 'owner'` then, if `detail == null`, always `context.replace('…/announcement/create')` without checking ownership. The follower empty state in `build()` (`AppEmptyState` + `emptyAnnouncementYet`) is unreachable because navigation happens first.

### 2. Owner-only routes have no route-level guard

`/baby/:babyId/announcement/create` builds `AnnouncementCreateScreen` for any member. Only some owner pages checked the role in-screen (`event_form_screen.dart`, `registry_shipping_address_screen.dart`); registry item forms, AI suggestions, baby edit and followers relied on the entry buttons being hidden.

### 3. Home CTA does not reflect announcement availability for followers

`HomeBirthWelcomeCard` always shows **View Announcement** for every role. `BirthWelcomeSummary.announcementId` is available from home-summary but unused, so followers see a button that implies content exists when it does not.

## Related code with the same flaw

| Location | Issue |
|----------|--------|
| `announcement_card_screen.dart` L67–68 | Redirect without `_isOwner` |
| `announcement_create_screen.dart` | No role check on load |
| `home_birth_welcome_card.dart` | View button always visible |

Owner home flow that pushes create after marking born (`home_screen.dart`) is correct — owners only.

## Fix

The deeper flaw is that owner-only pages had no route-level guard: each screen decided for itself whether to check the role, so a missed check (announcement create) let a follower reach an owner form. The fix moves the rule into the router.

| Layer | Change |
|-------|--------|
| `core/router/owner_only_gate.dart` (new) | `OwnerOnlyGate` resolves the baby (route `:babyId`, or the selected baby for tab routes). A known non-owner gets the shared `ownerOnlyPageBlocked` snackbar and `popOrGo(fallback)`; the screen is never built. An unresolved baby (offline, no cache) is left to the screen's own load. The API enforces the same rule. |
| `core/router/app_router.dart` | Every owner-only route builds through the gate (table below). |
| `event_form_screen.dart`, `registry_shipping_address_screen.dart` | In-screen role checks removed (the router covers them); per-feature "only owners" strings replaced by one shared string. |
| `announcement_card_screen.dart` | Redirect to create only when `_isOwner && detail == null`; followers get the empty state. |
| `home_birth_welcome_card.dart` | **View Announcement** shows for owners, or for followers when `announcementId != null`. |

### Owner-only routes (all gated)

| Route | Baby | Fallback |
|-------|------|----------|
| `/baby/:babyId/edit` | route | Home |
| `/baby/:babyId/followers` | route | Home |
| `/baby/:babyId/announcement/create` | route | announcement card |
| `/calendar/event/create`, `/calendar/event/:eventId/edit`, `/calendar/ai-suggestions` | selected | Calendar |
| `/registry/item/create`, `/registry/item/:itemId/edit`, `/registry/ai-suggestions`, `/registry/shipping-address` | selected | Registry |

`/invite-family` is not gated by role of the selected baby: it already targets the user's owned baby (`resolveOwnerBaby`) and handles "no owned baby" itself. Onboarding owner routes are only reachable inside the owner onboarding flow.

### Rule

A new owner-only page must be registered through `OwnerOnlyGate` in `app_router.dart`; screens do not re-check the role.

## Tests

- `owner_only_gate_test.dart`: owner sees the page; follower is turned back with feedback (route baby and selected baby); deep link with nothing to pop goes to the fallback; unresolved baby falls through to the screen.
- `announcement_card_screen_test.dart`: follower + no announcement → empty state; owner → create.
- `home_birth_welcome_card_test.dart`: follower without announcement hides the View button.

## References

- GitHub #370, pre-prod plan BABY-003 / ONB-007
- `apps/mobile/lib/features/announcement/presentation/announcement_card_screen.dart`
- `apps/mobile/lib/features/home/presentation/widgets/home_birth_welcome_card.dart`
