# RCA: Co-owner welcome shows `Luna''s` (ONB-008)

## Summary

The co-owner welcome body text renders a doubled apostrophe before “s profile” (e.g. `Luna''s`) instead of a possessive (`Luna's`).

## Root causes

### 1. ICU-style `''` escape in ARB without `use-escaping`

`app_en.arb` `inviteCoOwnerAccessBody` uses `{babyName}''s`. ARB escaping rules treat `''` as a literal apostrophe **only** when `l10n.yaml` sets `use-escaping: true`. This project’s `l10n.yaml` does not enable it, so `flutter gen-l10n` emits the two quotes literally into `app_localizations_en.dart` (`$babyName\'\'s`).

### 2. Single occurrence, but pattern is easy to repeat

A repo-wide search shows `''` appears only in `inviteCoOwnerAccessBody`. Other possessives in `app_en.arb` use a single `'` inside the JSON string (e.g. `baby's`), which is correct for non-escaping mode.

Enabling `use-escaping: true` globally would require auditing every ARB string for `{` / `}` / `'` rules — higher risk than fixing the one mistaken `''`.

## Related code with the same flaw

| File | Note |
|------|------|
| `app_en.arb` L748 | `{babyName}''s` |
| `app_localizations_en.dart` | Generated duplicate `\'\'` |
| `invite_landing_widgets.dart` | Displays `inviteCoOwnerAccessBody` |

No other locale ARB files in the repo.

## Fix direction

| Layer | Change |
|-------|--------|
| `app_en.arb` | `{babyName}'s` (single apostrophe in JSON string) |
| `app_localizations_en.dart` | Regenerated output aligned with ARB (CI runs gen-l10n on Mac) |
| Tests | Unit/widget assertion that co-owner body contains `Luna's` not `Luna''s` |

Do **not** enable `use-escaping` in this change set unless all ARBs are migrated.

## References

- GitHub #376, pre-prod plan ONB-008
- `apps/mobile/lib/l10n/app_en.arb`, `apps/mobile/l10n.yaml`
- `apps/mobile/lib/features/invitations/presentation/widgets/invite_landing_widgets.dart`
