# RCA: Onboarding batch invite form error clipped (#429)

## Summary

On owner onboarding **Invite family & friends**, tapping **Send Invites** with an invalid email shows the per-row inline error correctly, but the form-level summary (`batchInviteInvalidEmails`) is rendered **below Skip for now** at the bottom of the scroll content. On a tall phone with multiple rows, it sits under the system gesture bar and is not scrolled into view.

## Root cause

1. **Layout order** — `BatchInviteScreen._inviteRows` placed the `_error` text after the onboarding **Skip for now** link (lines 359–388), so the summary is the last child in a long column.

2. **Nested scroll** — Onboarding mode wrapped `_onboardingBody()` in an extra `SingleChildScrollView` inside `OnboardingScaffold`, which already scrolls `body`. That made scroll padding and visibility less predictable.

3. **No scroll-to-error** — `_finish` set `_error` on validation failure but did not call `Scrollable.ensureVisible` for the summary or the first invalid row.

4. **Scroll bottom inset** — `OnboardingScaffold` scroll padding had no extra bottom inset for long onboarding forms, so the last lines of scroll content could sit flush against the safe-area edge.

## Fix

| Layer | Change |
|-------|--------|
| `BatchInviteScreen` | Show form-level `_error` immediately below **Send Invites** (above Skip). Remove the redundant inner `SingleChildScrollView` in onboarding mode. On validation failure, scroll to the first invalid row via a `GlobalKey` owned by each row's state (no parallel index-based key list). |
| `OnboardingScaffold` | Add a fixed 16 px bottom padding to the scroll view for every onboarding screen. The body is already inside `SafeArea`, so adding `viewPadding.bottom` here would double-pad; no screen adds its own system inset. |
| Tests | `batch_invite_validation_test.dart`: onboarding mode shows the summary above Skip and scrolls the invalid row into view (widget test with bounded viewport). |

## References

- GitHub #429, #422
- `apps/mobile/lib/features/invitations/presentation/batch_invite_screen.dart`
- `apps/mobile/lib/features/onboarding/presentation/widgets/onboarding_scaffold.dart`
