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

`insert_activity_event` also had no lock for **any** caller (gallery, registry, calendar, fun hub, worker photo-ready). The same race exists wherever a hard-delete overlaps a child `INSERT`, including grandchild rows (comments, squishes, RSVPs, likes, purchases) whose FK parent the baby delete cascades away.

Under READ COMMITTED, PostgreSQL does not re-check FK targets at commit time for plain inserts; the insert either sees the parent row at statement time or fails immediately.

### Fix (one mechanism)

| Layer | Change |
|-------|--------|
| `repositories/child_write_locks` (new) | `ensure_baby_profile(s)_for_child_write`: `FOR KEY SHARE` on the baby (several babies sorted by `id`), raising `NotFoundError` (404 `not_found`) when it is gone. `ensure_parent_row_for_child_write(parent, id)`: for rows whose FK points at a baby-owned parent (photo, event, announcement, name suggestion, registry item) it locks the parent's baby, then `FOR KEY SHARE` on the parent row. All locks are taken in the **same transaction** as the INSERT. |
| `repositories/activity_events` | Locks the baby before `INSERT`. `row_lock_held=True` skips the lock when the caller already holds `FOR UPDATE` (leave/remove). |
| `domain/member_lifecycle` | Leave and remove-member write membership **and** activity in one transaction under the baby `FOR UPDATE` (`row_lock_held=True`). Remove-member re-checks the target under the lock. |
| Direct baby children | Baby lock before INSERT: pending photos, events, name suggestions, registry items, first-moment seeds, birth announcements, data-export jobs. |
| Grandchildren | Parent-row lock before INSERT: photo comments/squishes, event comments/RSVPs, announcement comments/squishes, name-suggestion likes, registry purchases. |
| Photo baby tags | Uploader's baby + every tagged baby (sorted) + photo locked **before** the tag `DELETE`. |
| `main.py` | Global `DomainError` handler, so a `NotFoundError` that escapes a router's narrow `except` (data export, announce-arrival) still returns 404, not 500. |
| Worker | `mark_photo_ready` locks the baby (`FOR KEY SHARE`) **before** its photo `UPDATE` and returns `None` when the baby or pending photo is gone. Baby-scoped notifications lock the baby first, and `_deliver_to_inbox_and_push` skips inbox and push (logs `notify_skip_baby_deleted`) when it is gone. That skip is the only place a missing baby is swallowed. |

### Lock order / deadlocks

Every path locks `baby_profiles` first (ascending `id` when there are several, matching account delete), then the direct parent row, then INSERTs. Delete and membership mutations take `FOR UPDATE` on the baby; child writers take `FOR KEY SHARE`, which waits behind `FOR UPDATE` but not behind other writers. A writer that already holds a lock on a row the delete cascades into, and then waits for the baby, deadlocks with the delete. Review found and fixed three such orderings: name suggestion (membership row before baby), photo tags (tag `DELETE` and unsorted babies before the lock), and worker photo-ready (photo `UPDATE` before the baby). Leave/remove are the only paths that would need `FOR KEY SHARE` while holding `FOR UPDATE`; they skip it via `row_lock_held=True`.

**Out of scope (separate issue if wanted):** account delete vs a comment/RSVP by that same user. The FK is to `app_users`, not the baby, so this lock does not cover it.

## Impact analysis

Every SQL write path that references `baby_profiles` (directly, through a baby-owned parent, or by tagged baby id), and whether a concurrent sole-owner or account hard-delete can overlap it.

| Surface | Detail | Vulnerable before fix? | Covered by |
|---------|--------|------------------------|------------|
| **Activity feed** | `insert_activity_event` (leave, remove, gallery, home, registry, calendar, fun) | Yes (separate txn on leave/remove; all callers unguarded) | `test_delete_baby_profile_postgres.py`, `test_baby_child_write_delete_race_postgres.py` |
| **Worker photo ready** | `mark_photo_ready` → photo `UPDATE` + `activity_events` | Yes (PR's first version deadlocked) | `worker/tests/integration/test_photo_ready_baby_delete_race_postgres.py`, `test_mark_photo_ready.py` |
| **Worker notifications** | inbox rows with `baby_profile_id` | Yes | `test_notifications_fcm_data.py` (skip path) |
| **Photos (pending)** | `create_pending_photo` | Yes | `test_baby_child_write_delete_race_postgres.py` |
| **Photo comments / squishes** | FK to `photos` (cascaded by baby delete) | Yes: FK 500 | `test_baby_child_write_delete_race_postgres.py` (comment) |
| **Events, RSVPs, event comments** | `create_event`; RSVP/comment FK to `events` | Yes | Same lock helpers; calendar tests |
| **Birth announcement + comments/squishes** | `upsert_announcement`; FK to `birth_announcements` | Yes | Same lock helpers; announcement tests |
| **Fun hub** | `name_suggestions`; likes FK to suggestions | Yes (+ lock-order deadlock in suggest) | `test_fun_domain.py`, `test_baby_name_postgres.py` |
| **Registry** | `registry_items`; purchases FK to items | Yes | Registry tests |
| **Data export jobs** | `insert_export_job` (router only caught `PermissionError`/`RuntimeError`) | Yes: 500 | `test_data_export.py::test_data_export_baby_deleted_mid_request_is_404_not_500` |
| **Photo baby tags** | `photo_baby_tags.tagged_baby_profile_id` | Yes (+ deadlock risk) | Gallery tag tests |
| **First-moment seeds** | baby-scoped inserts | Yes | First-moment tests |
| **Invitations** | create / accept | No (`FOR UPDATE` baby) | `test_invitation_accept_race.py` |
| **Onboarding create baby** | new baby id | No | Onboarding tests |
| **Membership leave/remove** | `UPDATE baby_memberships` | No (`FOR UPDATE` baby) | delete-baby integration |
| **Baby hard-delete / account delete / storage cleanup jobs** | `FOR UPDATE` then delete, same txn | No | `test_delete_baby_profile_postgres.py`, `test_account_delete_storage_postgres.py` |
| **Purge / worker cleanup** | deletes only | No | Worker storage cleanup tests |

**API behaviour when delete wins:** the write returns 404 `not_found`. Leave/remove return `not_member` / `target_not_member` when the baby row is already gone.

## Regression test

| Item | Detail |
|------|--------|
| **Tests** | `test_baby_child_write_delete_race_postgres.py`: pending photo, activity event and photo comment, each racing an uncommitted delete in two modes (delete holds `FOR UPDATE` first; `DELETE` already ran). Asserts the write blocks, then `NotFoundError` 404 and zero rows. `test_delete_baby_profile_postgres.py`: concurrent co-owner leave + delete, with unhandled thread exceptions treated as errors. Worker `test_photo_ready_baby_delete_race_postgres.py`. Unit tests for the worker skip, the data-export 404 and lock calls. |
| **Fails on old code** | Run against `origin/main` app code: all 6 race cases fail (`ForeignKeyViolation` on `photos`, `activity_events`, `photo_comments`, or the comment write not serialized), and co-owner leave+delete fails 20/20 (`activity_events` FK). The worker race test fails on main (no lock) and on this PR's first revision (`DeadlockDetected`). |
| **Passes with fix** | All pass; the race tests looped 20× with no flakes. |

## References

- `services/api/src/lanonna_api/repositories/child_write_locks.py`
- `services/api/src/lanonna_api/domain/member_lifecycle.py`, `domain/fun.py`, `main.py`
- `services/api/src/lanonna_api/repositories/activity_events.py`, `photo_tags.py`
- `services/worker/src/lanonna_worker/db.py`, `notifications.py`
- `services/api/tests/integration/test_baby_child_write_delete_race_postgres.py`, `test_delete_baby_profile_postgres.py`
- `services/worker/tests/integration/test_photo_ready_baby_delete_race_postgres.py`
- GitHub #442
