# RCA: Issue #331 — Delete baby profile (sole owner)

## Summary

Users tried **Leave profile** in the baby switcher expecting the baby to be removed or deleted. Sole owners are blocked (`can_leave` false) with copy that mentions “delete this baby profile,” but no standalone delete-baby feature existed—only **account delete** soft-deleted sole-owned babies.

## Root cause

- **Product/API:** `FR-INV-010` intentionally forbids sole-owner leave; removal of a sole-owned baby was only implemented inside `soft_delete_account_rows` during account deletion.
- **Mobile:** One leave entry point (`baby_switcher_sheet.dart`) and misleading dialog text (`memberSoleOwnerLeaveBody`) referencing a non-existent delete-baby action.
- **Not a leave-endpoint bug:** `POST /v1/babies/{id}/leave` and `can_leave` behave as specified.

## Related code

| Area | Location |
|------|----------|
| Account delete SQL slice | `services/api/src/lanonna_api/repositories/account_delete.py` → shared `baby_profile_delete.soft_delete_baby_profiles` |
| Delete domain | `services/api/src/lanonna_api/domain/baby_delete.py` |
| Member lifecycle / leave | `services/api/src/lanonna_api/domain/member_lifecycle.py` |
| Babies router | `services/api/src/lanonna_api/routers/babies.py` (`DELETE /v1/babies/{id}`) |
| Owner count / `can_leave` | `repositories/babies.py` (`active_owner_count`), `domain/baby_summaries.py` |
| Former member access | `domain/membership_access.py` → `membership_ended`; list omits `deleted_at` babies |
| Mobile cache / selection | `BabyListCache`, `HomeRepository.resolveSelectedBaby`, `HomeRefreshSignal` |
| Push/worker | No fan-out on delete; same as account-delete sole-owned babies (activity feed only records live babies) |
| Storage / NFR-DATA-001 | Soft `baby_profiles.deleted_at` + ended memberships; GCS objects retained until ops hard-delete (same retention as account delete for sole-owned babies) |

## Decisions (implemented)

1. **`DELETE /v1/babies/{baby_profile_id}`** — owner-only; sole active owner only; `409 cannot_delete_shared_baby` when two owners (use leave).
2. **Shared soft-delete helper** extracted from account delete (revoke invites, soft-remove memberships, `deleted_at`, participation purge via existing membership helpers).
3. **Mobile:** Delete on Edit baby + switcher (sole owners get Delete instead of Leave); two-step confirm; cache invalidate + `resolveSelectedBaby` + `HomeRefreshSignal` like leave.
4. **No** mapping sole-owner leave to silent baby deletion.
5. **Atomic owner check:** delete (`soft_delete_baby_profile_if_sole_owner`) and leave (`soft_remove_own_membership`) each take the baby row lock (`lock_baby_profile_for_update`, the same lock co-owner invite/accept use), then count owners and write in one transaction. Two co-owners deleting/leaving at once can no longer both pass the count (before this, two simultaneous co-owner leaves could leave a baby with no owner).
6. **Shared rule on mobile:** `BabySummary.canDeleteProfile` (owner and server `can_leave == false`) decides Delete vs Leave on both entry points.

## Test plan

- **API domain:** sole-owner delete succeeds; co-owned delete raises `cannot_delete_shared_baby`; non-owner forbidden.
- **API router:** `DELETE` returns 204 / mapped errors.
- **Postgres integration:** baby gone from `GET /v1/babies`; follower gets `membership_ended` on baby route; pending invites revoked.
- **Account delete:** still soft-deletes sole-owned babies via shared helper (existing tests updated if needed).
- **Postgres concurrency:** simultaneous co-owner delete + leave never orphans the baby; simultaneous co-owner leaves keep exactly one owner.
- **Mobile:** `AccountRepository.deleteBabyProfile` invalidates list; widget test for the two-step confirm; `canDeleteProfile` unit test (delete vs leave).
- **Parity:** `ErrorCode` / `ApiErrorCode` + `test_error_code_parity.py`.
