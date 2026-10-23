# RCA: Invite "Open" no-op when already a member (#374)

## Summary

A signed-in user who opens an **already-accepted** follower invite deep link (`lanonna://app/invite-accept?token=…`) sees the landing screen ("You're already a member", baby card, **Open**). Tapping **Open** does nothing: no navigation and no API call.

## Root cause

The landing screen's primary CTA (`Open` when accepted, `Accept` when pending) had two silent exits and one uncaught path:

1. `openAcceptedInvitePreview` returned silently when `OnboardingCoordinator.pendingInviteToken` was null or empty. The token can be gone while an accepted preview is still on screen (e.g. `setPendingInviteToken(null)` after an earlier accept, while `invitePreviewJson` / `invitedBabyId` remain; `completeInviteOnboarding` only flips the completed flag). `clearPendingInvite` clears token **and** preview together, so it is not the source.
2. The pending-invite `Accept` path returned silently with no token as well.
3. Errors thrown by the accept / navigation helpers (API failure, `already_member` with no baby id) were not caught by the screens, so the tap appeared to do nothing.

For a real deep link (`lanonna://app/invite-accept?token=…`) `InviteAcceptBootstrapScreen` binds the token, so Open → `POST /v1/invitations/accept` → `already_member: true` + `baby_profile_id` → baby home. The API already returns that body for members; no API change is needed.

## Fix

| Layer | Change |
|-------|--------|
| `invite_flow_navigation.dart` | New shared `runInviteLandingPrimaryAction(context, preview)` used by both the follower and co-owner landing screens. It runs Open (accepted) or Accept (pending) and returns `null` on success or a user-facing message via `apiErrorMessage` — never a silent return. |
| `openAcceptedInvitePreview` | Token present → accept API (handles `already_member`). No token → go home with the cached `babyProfileId` / invited id. Neither → throws `InviteAcceptException('not_found')`. |
| `_acceptPendingInvite` | No token → `not_found`; signed out → signup with the invite email prefilled; else accept. |
| `continueToJoinedBabyHome` | No baby id → throws `not_found` instead of a local snackbar, so the screen shows one consistent problem state. |
| Follower / co-owner invite screens | `_onPrimary` sets the existing problem message from the returned string; removed per-screen accept code. |

## Tests

`test/invite_flow_navigation_test.dart`:

- Accepted preview, cleared token → Open goes to the baby without an API call.
- Deep link (token present), accept returns `already_member` → baby home.
- No token and no cached preview → "This invitation link is invalid or was revoked."
- Pending preview, no token → same not-found message.
- Refused accept → mapped message, no navigation.

## Known gap

There is no Inbox entry that opens an invite for the invitee: `invite_accepted` goes to the inviter's owner-gated followers page. The invite deep link / email is the only invitee entry point.

## References

- Issue #374
- `apps/mobile/lib/features/onboarding/data/onboarding_storage.dart`
- `apps/mobile/lib/features/onboarding/presentation/utils/invite_flow_navigation.dart`
