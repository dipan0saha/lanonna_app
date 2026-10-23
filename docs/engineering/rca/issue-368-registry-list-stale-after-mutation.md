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

## Fix direction

| Layer | Change |
|-------|--------|
| `registry_item_form_screen.dart` | Pop `true` on successful create **and** edit (match event form) |
| `registry_screen.dart` | Shared `_openItemForm` / edit helper: `await context.push<bool>(…)` then `_load()` when `true` |
| Tests | Widget test: fake registry repo counts `listItems` before/after simulated form return |

## References

- GitHub #368, `docs/qa/pre-prod-test-plan.md` REG-002
- `apps/mobile/lib/features/registry/presentation/registry_screen.dart`
- `apps/mobile/lib/features/registry/presentation/registry_item_form_screen.dart`
- `apps/mobile/lib/features/calendar/presentation/calendar_screen.dart` (`_openCreateEvent`)
