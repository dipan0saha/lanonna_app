# RCA: Issue #394 — Follower Home hides upcoming events

## Summary

When a baby has future calendar events, **owner** Home shows the “NEXT UP” card, but **follower** Home showed no upcoming events at all—even though `home-summary` returns both `next_up_event` and `teasers.upcoming_events`.

## Root cause

`HomePrdSections` passed `includeUpcomingEvents: summary.nextUpEvent == null` into `HomeTeasersSection`, assuming `HomeNextUpSection` would cover the next event. That section was only built in `OwnerHomeComposer` (expecting flow). Followers therefore lost both surfaces whenever `next_up_event` was set.

## Fix

Centralize per-role Home rules in `HomeComposition`:

- `showNextUpCard` — when `next_up_event` is present (owners **and** followers).
- `includeUpcomingEventsTeaser` — when there is no next-up card but teaser events exist.

Wire owners and followers through the same helpers; render `HomeNextUpSection` in `FollowerHomeComposer` when `HomeComposition.showNextUpCard` is true.

## Test plan

- Extend `follower_home_composer_test.dart`: follower with `nextUpEvent` on summary shows NEXT UP title.
- `home_composition_test.dart` unit tests for teaser vs next-up mutual exclusion.
