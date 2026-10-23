# RCA: Invite link for a baby you already belong to (#374)

## Summary

A signed-in user who opens an **already-accepted** invite deep link for a baby they already belong to (as owner, co-owner, or follower) sees the landing copy **"You're already a member"** and **Open**. Tapping **Open** must take them to that baby's Home without calling accept and without error.

Pre-prod QA reproduced two failures on main:

1. **Original (#374):** **Open** did nothing — no navigation and no API call.
2. **After PR #385:** **Open** called `POST /v1/invitations/accept`, returned **403 `email_mismatch`**, and routed to **Wrong account** — even though the signed-in user is an owner of the baby and the landing already implied membership.

## Why PR #385 did not fully fix it

PR #385 removed silent no-ops in `runInviteLandingPrimaryAction` / `openAcceptedInvitePreview` and wired **Open** to always call `acceptSignedInInviteAndContinue` when `pendingInviteToken` was still set (the normal deep-link path). That fixed the dead button when the token had been cleared but a cached accepted preview remained.

It did **not** change the contract for an **accepted** invite (status `accepted` in the preview):

- The landing headline **"You're already a member"** is shown whenever `preview.isAccepted` is true — meaning the invitation row was already consumed, not that the API verified the viewer's membership.
- With a token present, **Open** still hit **accept**, which enforced **invitee email == signed-in email** before checking **baby membership**. An owner opening a follower invite addressed to someone else therefore got `email_mismatch` instead of idempotent `already_member` or a direct navigation.

The correct product rule is: **if the viewer already belongs to the baby, Open goes Home with no accept**, regardless of invitee email or invitation status display copy.

## Root cause

| Layer | Issue |
|-------|--------|
| Mobile | `openAcceptedInvitePreview` treated "token present" as "must POST accept". For `preview.isAccepted`, membership should be resolved first (local baby list / `GET /v1/babies`), then navigate with `continueToJoinedBabyHome` — never accept. |
| API | `accept_invitation_by_token` ran `_email_mismatch` **before** the `baby_memberships` lookup that returns `already_member: true`. Any member who was not the original invitee got 403 on accept paths that still call the API (pending invite, complete-profile resume, etc.). |

## Fix

| Layer | Change |
|-------|--------|
| Mobile `invite_flow_navigation.dart` | For accepted previews: if the signed-in viewer belongs to `preview.babyProfileId`, finish invite onboarding and go Home **without** accept. If the invite is accepted and the viewer is **not** a member, surface `already_used` (invitation consumed by someone else). Pending invites unchanged: accept when appropriate. |
| API `accept_invitation_by_token` | After loading the invitation row, resolve existing membership **before** email mismatch. Existing members always get `already_member` + `baby_profile_id` idempotently. Email mismatch applies only to non-members who are not allowed to accept. |
| Tests | Flutter widget tests: accepted + token + membership → no accept, Home. API pytest: member with non-invitee email → `already_member`, not 403. |

## Resume consistency (#388 / #391)

Invite resume after kill still hydrates token + cached preview on the landing screens. **Open** on an accepted preview uses the same membership-first navigation, so cold start, warm deep link, and resume-after-kill behave the same.

## References

- GitHub #374, PR #385
- `apps/mobile/lib/features/onboarding/presentation/utils/invite_flow_navigation.dart`
- `services/api/src/lanonna_api/repositories/invitations.py`
