# RCA: Help & support mailto subject shows `La+Nonna+support` (#419)

## Summary

Settings → Help & support opens the device mail composer with the correct support address, but the subject line shows literal plus signs instead of spaces (`La+Nonna+support` instead of `La Nonna support`).

## Root cause

`_openHelp` in `settings_screen.dart` built the mailto URI with `Uri(scheme: 'mailto', path: ..., queryParameters: {'subject': 'La Nonna support'})`. Dart encodes `queryParameters` using HTML form encoding (space → `+`). RFC 6068 mailto URIs expect percent-encoding (`%20`). Gmail and most clients display `+` literally in the subject field.

No shared mailto builder existed; any future mailto link would repeat the same mistake.

## Fix

| Layer | Change |
|-------|--------|
| `core/platform/mailto_uri.dart` | Shared `buildMailtoUri` that builds the `query` string with `Uri.encodeComponent` per RFC 6068. |
| `settings_screen.dart` | Use `buildMailtoUri` for Help & support. |
| Tests | Unit tests assert the serialized URI uses `%20`, not `+`, in the subject. |

## References

- GitHub #419
- `apps/mobile/lib/features/settings/presentation/settings_screen.dart`
- `apps/mobile/lib/core/platform/mailto_uri.dart`
