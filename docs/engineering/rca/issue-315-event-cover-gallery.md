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
- API init accepts a typed `purpose` (unknown values are rejected; no endpoint changes it later). Every gallery surface filters `purpose = 'gallery'`: list, home teasers, the home "first photo" checklist, and the photo item endpoints (detail, squish, comments, caption, tags, delete), so `/gallery/photo/{cover id}` is "not found". Event detail still resolves its cover with an unfiltered lookup. The storage meter keeps counting covers.
- Worker skips `photo_shared` activity/notify when `purpose = event_cover`; thumbnails unchanged.
- Mobile uploads covers through `DisplayPhotoUpload` with `PhotoPurpose.eventCover`; no `notifyGalleryDataChanged` for new cover uploads. When the stored cover's signed URL expires in the edit form, the preview is re-read from the event (`cover_photo_display_url`), because the gallery photo endpoint does not serve event-only covers.
- **Lifecycle:** migration 040 makes `events.cover_photo_id` `ON DELETE SET NULL`, so deleting a gallery photo used as a cover clears that cover. Replacing or removing a cover, or deleting its event, purges the old photo in one `DELETE` only when it is `event_cover` and no event or announcement still uses it; gallery photos are never purged. Both paths go through `photo_lifecycle` and remove the display and thumb objects best-effort after the row is gone.

## Related gaps addressed

- Gallery delete failed on FK when photo was an event cover.
- Orphan `event_cover` rows after event delete or cover replacement.
