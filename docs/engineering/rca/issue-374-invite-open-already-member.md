# RCA: Invite "Open" no-op when already a member (#374)

## Summary

A signed-in user who opens an **already-accepted** follower invite deep link (`lanonna://app/invite-accept?token=…`) sees the landing screen ("You're already a member", baby card, **Open**). Tapping **Open** does nothing: no navigation and no API call.

## Root cause

`openAcceptedInvitePreview` (`invite_flow_navigation.dart`) requires `OnboardingCoordinator.pendingInviteToken` and **returns silently** when the token is null or empty.

After a prior successful invite onboarding, `completeInviteOnboarding` / `clearPendingInvite` removes the pending token from `OnboardingStorage` but **keeps** `invitePreviewJson` (cached preview). Cold-starting on an invite deep link can hydrate the landing UI from cache while the token is already cleared, so `isAccepted == true` but Open has no token to pass to `acceptSignedInInviteAndContinue`.

The primary CTA therefore becomes a no-op with no user feedback — inconsistent with other invite actions that always navigate or surface an error.

## Fix direction

| Layer | Change |
|-------|--------|
| `invite_flow_navigation.dart` | Extract `goHomeForAcceptedInviteMember` — select baby from preview / invited id and call `finishInviteOnboardingAndGoHome` |
| `openAcceptedInvitePreview` | If token present → accept API path; else if cached preview is `accepted` with `babyProfileId` → home navigation path; else show alert (never silent return) |
| Tests | Widget test: accepted preview, cleared token, tap Open → navigates (mock home / router) |

## References

- Issue #374
- `apps/mobile/lib/features/onboarding/data/onboarding_storage.dart`
- `apps/mobile/lib/features/onboarding/presentation/utils/invite_flow_navigation.dart`
