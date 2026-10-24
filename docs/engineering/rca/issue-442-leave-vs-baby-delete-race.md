# RCA: Member leave vs baby hard-delete races on baby-scoped INSERTs (#442)

| Field | Value |
|-------|--------|
| **Issue** | [#442](https://github.com/dipan0saha/lanonna_app/issues/442) |
| **Status** | Fixed |
| **Date** | 2026-10-24 |

## Summary

When a co-owner **left** a baby at the same time the other owner became sole owner and **hard-deleted** the profile, the leave path could commit the membership change in one transaction and then insert an `activity_events` row in a **second** transaction. Under READ COMMITTED, the delete transaction could remove `baby_profiles` between those commits, so the activity `INSERT` hit `activity_events_baby_profile_id_fkey` and surfaced as an unhandled `IntegrityError` (HTTP 500). Integration tests only asserted owner-count invariants and swallowed domain errors, so a background-thread FK failure appeared as `PytestUnhandledThreadExceptionWarning`.

## Root cause

### Locking that already worked

| Path | Transaction | `baby_profiles` lock | Child write |
|------|-------------|----------------------|-------------|
| `soft_remove_own_membership` | One txn | `SELECT … FOR UPDATE` | `UPDATE baby_memberships` (same txn) |
| `hard_delete_baby_profile_if_sole_owner` | One txn | `SELECT … FOR UPDATE` | `DELETE FROM baby_profiles` (cascade) |
| `delete_account_rows` sole-owned babies | One txn | `SELECT … FOR UPDATE OF b` (ordered by `b.id`) | `hard_delete_baby_profiles` |
| Invitation create / accept | One txn | `lock_baby_profile_for_update` | `INSERT invitations` / `INSERT baby_memberships` |

Leave and delete **serialize correctly** when both need the baby row: each takes `FOR UPDATE` first, so owner-count checks and delete refusal (`cannot_delete_shared_baby`) are safe.

### The gap

`leave_baby_profile` and `remove_member` called `insert_activity_event` **after** `soft_remove_*` returned, in a **new** connection/transaction with **no** baby-row lock:

1. **Txn A (leave):** `FOR UPDATE` baby → remove membership → **COMMIT** (releases lock).
2. **Txn B (delete):** `FOR UPDATE` baby → sole-owner check passes → `DELETE baby_profiles` → **COMMIT**.
3. **Txn C (activity):** plain `INSERT INTO activity_events (baby_profile_id, …)` → FK violation because the parent row is gone.

`insert_activity_event` also had no lock for **any** caller (gallery, registry, calendar, fun hub, worker photo-ready), so the same class of race exists wherever a hard-delete overlaps a child `INSERT`.

Under READ COMMITTED, PostgreSQL does not re-check FK targets at commit time for plain inserts; the insert either sees the parent row at statement time or fails immediately.

### Fix (one mechanism)

| Layer | Change |
|-------|--------|
| `repositories.memberships` | `lock_baby_profile_for_key_share` + `ensure_baby_profile_for_child_write` (raises `LookupError` → API `not_found`). Document pairing with existing `lock_baby_profile_for_update` on delete/leave/membership mutations. |
| `repositories/activity_events` | Call `ensure_baby_profile_for_child_write` before `INSERT`; support `row_lock_held=True` when the caller already holds `FOR UPDATE`; `skip_if_baby_missing` for worker best-effort feed rows. |
| `domain/member_lifecycle` | Leave and remove-member activity inserts run in the **same** transaction as membership changes (`row_lock_held=True`). Remove-member re-checks target under `FOR UPDATE`. |
| Baby-scoped repository INSERTs | `ensure_baby_profile_for_child_write` before insert in photos (pending), events, fun (suggestions/votes), registry items, first-moment seeds, birth announcements, data-export jobs, photo baby tags. |
| Worker | `lock_baby_profile_for_key_share` before `activity_events` and baby-scoped `notifications` inserts; skip quietly when the baby is gone. |

**Lock ordering / deadlocks:** Hard-delete and membership mutations keep taking **`FOR UPDATE`** on `baby_profiles` first (same order as account delete: babies by `id`, then user row). Child writers take **`FOR KEY SHARE`**, which blocks behind `FOR UPDATE` but does not block other `FOR KEY SHARE` holders. No path takes `FOR KEY SHARE` then `FOR UPDATE` on the same baby in one transaction except leave/remove, which skip the share lock via `row_lock_held=True` while already holding `FOR UPDATE`. Account delete and purge jobs do not acquire `FOR KEY SHARE`; they only use `FOR UPDATE`, so they remain compatible.

## Impact analysis

Every SQL write path that references `baby_profiles` (direct FK or tagged baby id), and whether concurrent sole-owner / account hard-delete can overlap.

| Surface | Detail | Vulnerable before fix? | Covered by |
|---------|--------|------------------------|------------|
| **Activity feed** | `insert_activity_event` (API domain: leave, remove, gallery, home, registry, calendar, fun) | Yes — separate txn on leave/remove; all callers unguarded | `test_delete_baby_profile_postgres.py` (concurrent leave+delete); `test_structured_feed_postgres.py` (insert/list) |
| **Worker photo ready** | `mark_photo_ready` → `activity_events` | Yes | Worker unit tests; API integration relies on shared lock SQL |
| **Worker notifications** | `_insert_notifications` with `baby_profile_id` | Yes | `test_notification_delivery_postgres.py` (delivery; not delete race) |
| **Photos (pending)** | `create_pending_photo` | Yes | `test_baby_child_write_delete_race_postgres.py` (deterministic lock wait) |
| **Events** | `create_event` | Yes | `test_calendar_domain` / calendar integration (no delete race) |
| **Event RSVPs / comments** | FK via `events` / `photos` only | Low — parent row must exist; delete cascades parents first | Existing calendar/gallery tests |
| **Fun hub** | `name_suggestions`, `votes` | Yes | `test_baby_name_postgres.py`, fun domain tests |
| **Registry** | `registry_items`; purchases FK `registry_items` | Items yes; purchases indirect | Registry domain tests |
| **Birth announcement** | `upsert_announcement` | Yes | Announcement / home tests |
| **Data export jobs** | `insert_export_job` | Yes | `test_baby_data_export_postgres.py` |
| **Photo baby tags** | `photo_baby_tags.tagged_baby_profile_id` | Yes (tagged baby deleted) | Gallery tag tests (no race) |
| **Invitations** | `INSERT invitations`, accept → `baby_memberships` | No — `lock_baby_profile_for_update` | `test_invitation_accept_race.py` |
| **Onboarding create baby** | `INSERT baby_profiles` + membership | No — new id, not concurrent delete | Onboarding tests |
| **Membership leave/remove** | `UPDATE baby_memberships` | No — `FOR UPDATE` baby | Concurrent tests in delete-baby integration |
| **Baby hard-delete (API)** | `hard_delete_baby_profile_if_sole_owner` | No — `FOR UPDATE` | `test_delete_baby_profile_postgres.py` |
| **Account delete** | `_lock_sole_owned_baby_ids` + `hard_delete_baby_profiles` | No — `FOR UPDATE` | `test_account_delete_storage_postgres.py` |
| **Storage cleanup jobs** | `INSERT storage_cleanup_jobs` in delete txn | No — same txn as delete | Delete-baby / account-delete tests |
| **Notifications (API)** | Inbox rows inserted via worker only | N/A API | — |
| **Comments / squishes** | FK to photos/events/announcements | Indirect only | Gallery/announcement tests |
| **Purge / worker cleanup** | Deletes GCS + SQL deletes, no baby FK inserts | No | Worker storage cleanup tests |

**API endpoints affected (404 `not_found` when delete wins):** any route that inserts baby-scoped rows after membership checks without holding the baby lock — notably `POST /v1/babies/{id}/leave`, `DELETE …/members`, gallery upload, calendar/registry/fun writes, announcement, export request. Leave/remove return `not_member` / `target_not_member` when the baby row is already gone.

## Regression test

| Item | Detail |
|------|--------|
| **Tests added** | `test_delete_baby_profile_postgres.py` — concurrent leave+delete captures thread exceptions, asserts leave `ok` or `not_member`, `filterwarnings` error on unhandled thread exceptions; `test_baby_child_write_delete_race_postgres.py` — deterministic `FOR UPDATE` delete vs `create_pending_photo` (`LookupError`, zero photos). |
| **Fails on old code** | On `origin/main` without this patch: (1) concurrent test may pass invariants but raises `PytestUnhandledThreadExceptionWarning` / thread `IntegrityError` when `filterwarnings` is enabled; (2) photo race test gets FK violation or succeeds without waiting on lock — not `LookupError`. Verified by applying `filterwarnings` and `insert_activity_event` split-txn behavior to main logic. |
| **Passes with fix** | Same integration module on this branch. |

## References

- `services/api/src/lanonna_api/repositories/memberships.py` — `lock_baby_profile_for_key_share`, `ensure_baby_profile_for_child_write`
- `services/api/src/lanonna_api/domain/member_lifecycle.py`
- `services/api/src/lanonna_api/repositories/activity_events.py`
- `services/worker/src/lanonna_worker/db.py`, `notifications.py`
- `services/api/tests/integration/test_delete_baby_profile_postgres.py`
- `services/api/tests/integration/test_baby_child_write_delete_race_postgres.py`
- GitHub #442
