# RCA: Issue #315 — Event cover photos appear in Gallery

| Field | Value |
|-------|--------|
| **Issue** | [#315](https://github.com/dipan0saha/lanonna_app/issues/315) |
| **Status** | Fixed (new uploads only; no backfill) |
| **Date** | 2026-10-18 |

## Summary

Uploading a **new** event cover used the gallery upload path (`POST /v1/photos/init` via `GalleryRepository.uploadPhoto`), inserting a row in `photos` with no distinction from intentional gallery shares. Gallery list queries, home teasers, and the worker’s `photo_shared` activity/notifications treated every ready photo the same, so covers surfaced in Gallery and follower feeds.

## Root cause

1. **Single `photos` table** with no purpose/kind column (`002_core_domain.sql`).
2. **Mobile** (`event_form_screen.dart`) called `GalleryRepository.uploadPhoto` on save and `notifyGalleryDataChanged`, coupling covers to gallery refresh semantics.
3. **API** `list_photos_for_baby` filtered only by `baby_profile_id` and optional `status` / sort — not by intent.
4. **Worker** `mark_photo_ready` always inserted `photo_shared` activity and fanned out `PHOTO_SHARED` notifications for every display finalize.

PR #330 / L-37 (2026-10-17) fixed cover **UX** (#65: preview, upload-on-save, cancel orphans) but intentionally kept `GalleryRepository.uploadPhoto` for covers; it did not address #315.

## Expected behavior (product)

- **Prototype:** event photos live on the event (`pendingEventPhotoDataUrl` / `events[].photo`), not in `state.gallery` (`nonna_combined_prototype.html`).
- **Requirements pattern:** baby profile photo is avatar-only unless the user opts into gallery (#394); calendar covers are decorative attachments, not gallery moments unless the owner picks an existing gallery photo.

## Fix (architecture)

- Add `photos.purpose` (`gallery` | `event_cover`), default `gallery` — no backfill; existing rows remain `gallery`.
- API init accepts `purpose`; gallery surfaces filter `purpose = 'gallery'`; event detail still resolves cover via `get_photo_for_baby`.
- Worker skips `photo_shared` activity/notify when `purpose = event_cover`; thumbnails unchanged.
- Mobile uploads covers through `DisplayPhotoUpload` with `PhotoPurpose.eventCover`; no `notifyGalleryDataChanged` for new cover uploads.
- **Lifecycle:** deleting a gallery photo clears `events.cover_photo_id` first; replacing/removing/deleting event covers purges unreferenced `event_cover` rows (and GCS objects best-effort, same as gallery delete).

## Related gaps addressed

- Gallery delete failed on FK when photo was an event cover.
- Orphan `event_cover` rows after event delete or cover replacement.
