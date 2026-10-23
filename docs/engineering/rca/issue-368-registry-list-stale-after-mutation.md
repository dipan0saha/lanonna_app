# RCA: Registry list stale after create or edit (REG-002)

## Summary

After a successful `POST` or `PATCH` on a registry item, the Registry tab keeps showing the previous list until the user restarts the app or performs another action that calls `_load()` (claim, delete, undo). API responses are correct; the client never refetches `GET …/registry/items`.

## Root causes

### 1. Form routes pushed without awaiting a result

`RegistryScreen` opens create/edit via fire-and-forget `context.push` in three places (empty-state CTA, row edit, FAB). Unlike shipping address (`_openShippingEditor` awaits `push<bool>` and reloads) and calendar events (`calendar_screen.dart` `_openCreateEvent`), nothing triggers `_load()` when the form closes.

### 2. Edit save pops `false`, breaking a `true`-only reload contract

`RegistryItemFormScreen._save()` calls `context.pop(!widget.isEdit)`, so creates return `true` but edits return `false`. Any caller that reloads only when the result is `true` would skip edit refreshes. `EventFormScreen` always pops `true` on successful save.

### 3. Home-only refresh signal after save

On success the form calls `HomeRefreshSignal.notifyHomeShouldRefresh()` (home tab / teasers) but not the registry tab. Registry state lives only in `RegistryScreen` local fields (`_items`), not in a shared repository cache with listeners.

## Related code with the same flaw

| Location | Pattern |
|----------|---------|
| `registry_screen.dart` | `context.push(RegistryRoutes.createItem)` / `itemEdit` without await |
| `registry_item_form_screen.dart` | `pop(!widget.isEdit)`; home refresh only |
| `home_screen.dart` | `onRegistry` pushes create without registry reload (cross-tab; lower severity) |

No in-flight cache on `RegistryRepository` — stale UI is purely missing `_load()`.

## Fix

The right layer is the repository, not the route. A route result reaches only the screen that pushed the form. Home's **Add registry item** quick action and AI suggestions also create items while the Registry tab stays mounted in the shell, and they could never refresh it that way. `CalendarRepository`, `GalleryRepository` and `NotificationsRepository` already notify on change.

| Layer | Change |
|-------|--------|
| `RegistryRepository` | `ChangeNotifier`; `notifyListeners()` after every successful create, update, delete, claim, undo and shipping-address update. Provided with `ChangeNotifierProvider`. |
| `RegistryScreen` | Listens to the repository and reloads. All `push<bool>` result handling (item form, shipping editor) and the explicit reloads after claim/delete/undo are removed. |
| `RegistryAiSuggestionsScreen` | Listens instead of awaiting the form's pop result, so "added" marks update for any change. |
| `RegistryItemFormScreen`, `RegistryShippingAddressScreen` | `pop()` with no result. |

### Same approach app-wide (audit of create/edit forms)

| Form | Before | Now |
|------|--------|-----|
| Calendar event create/edit | `CalendarScreen` listened **and** reloaded on `push<bool>` (double load) | Listener only. `EventAiSuggestionsScreen` reloads via the listener; its pop result drives only the "added to calendar" confirmation. |
| Announcement create/edit | Card awaited `push<bool>`; squish/comment reloaded by hand | `AnnouncementRepository` is a `ChangeNotifier` (save, squish, comment); the card listens; `showAnnouncementCardAfterSave` pops with no result. |
| Baby profile create/edit, account edit | `HomeRefreshSignal` / `AccountRepository` notifier | Unchanged (already signal-based). |
| Gallery upload, comments | `GalleryRepository` notifier | Unchanged. |

**Rule:** data freshness comes from repository change notifications. A route result may only drive one-off UI feedback (a snackbar), never a reload.

## Tests

`registry_screen_mutation_refresh_test.dart` uses the real repository mutation methods over a stubbed HTTP client. Saving from the create and edit routes (popped with no result) reloads the tab, and so does a delete made outside the tab.

## References

- GitHub #368, `docs/qa/pre-prod-test-plan.md` REG-002
- `apps/mobile/lib/features/registry/presentation/registry_screen.dart`
- `apps/mobile/lib/features/registry/presentation/registry_item_form_screen.dart`
- `apps/mobile/lib/features/calendar/presentation/calendar_screen.dart` (`_openCreateEvent`)
