# RCA: Help & support mailto subject shows `La+Nonna+support` (#419)

## Summary

Settings → Help & support opens the device mail composer with the correct support address, but the subject line shows literal plus signs instead of spaces (`La+Nonna+support` instead of `La Nonna support`).

## Root cause

`_openHelp` in `settings_screen.dart` built the mailto URI with `Uri(scheme: 'mailto', path: ..., queryParameters: {'subject': 'La Nonna support'})`. Dart encodes `queryParameters` using HTML form encoding (space → `+`). RFC 6068 mailto URIs expect percent-encoding (`%20`). Gmail and most clients display `+` literally in the subject field.

No shared mailto builder existed; any future mailto link would repeat the same mistake.

## Fix

| Layer | Change |
|-------|--------|
| `core/platform/mailto_uri.dart` | `buildMailtoUri({address, subject})` is the only mailto builder in `lib/`. It builds `query` with `Uri.encodeComponent` (RFC 6068), so a space becomes `%20` and reserved characters such as `&` and `?` are escaped. An empty subject leaves the query out. |
| `settings_screen.dart` | Help & support calls `buildMailtoUri`. The subject comes from l10n (`settingsSupportEmailSubject`) instead of a hardcoded string. |
| Tests | `mailto_uri_test.dart` checks the serialized URI: `%20` rather than `+`, reserved characters escaped, and no query when there is no subject. |

An unused `body` parameter in the first draft was removed. Add it back only when a caller needs it.

## References

- GitHub #419
- `apps/mobile/lib/features/settings/presentation/settings_screen.dart`
- `apps/mobile/lib/core/platform/mailto_uri.dart`
