# RCA: Issue #394 — Follower Home hides upcoming events

## Summary

When a baby has future calendar events, **owner** Home (expecting) shows the "NEXT UP" card. **Follower** Home showed no upcoming events at all, even though `home-summary` returns both `next_up_event` and `teasers.upcoming_events`.

## Root cause

`HomePrdSections` passed `includeUpcomingEvents: summary.nextUpEvent == null` into `HomeTeasersSection`. That assumed `HomeNextUpSection` would always cover the nearest event, but it was only built in the expecting branch of `OwnerHomeComposer`. The API sets `next_up_event` whenever there is any upcoming event, for every role and lifecycle. So the strip was hidden everywhere while the card appeared in only one place:

- **Expecting follower:** no NEXT UP card, no strip. This is the reported bug.
- **Born owner and born follower:** the same loss. Born Home has no NEXT UP card (the prototype's `home-born` screen), so the strip is its only events surface.

## Fix

`HomeComposition` (`features/home/domain/home_composition.dart`) owns both decisions, so they can't drift apart again:

- `showNextUpCard(summary)`: expecting Home with a `next_up_event`, for owners **and** followers.
- `includeUpcomingEventsTeaser(summary)`: exactly `!showNextUpCard(summary)`. The strip is hidden only when NEXT UP is really rendered.

Both expecting composers render `HomeNextUpSection` through `showNextUpCard`. `HomePrdSections` uses `includeUpcomingEventsTeaser`.

**Follower safety:** NEXT UP links only to the calendar's upcoming list and to event detail. Followers already reach both (to view and RSVP). It exposes no edit, create or invite actions, and owner-only routes stay guarded by the router (#383).

## Test plan

- `home_composition_test.dart`: expecting with next up → card, no strip; expecting without → strip; born with next up → strip, no card.
- `follower_home_composer_test.dart`: an expecting follower with `next_up_event` sees NEXT UP and no owner actions; a born follower with `next_up_event` still sees UPCOMING EVENTS.
