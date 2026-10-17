import 'package:lanonna/l10n/app_localizations.dart';

// A baby's name is optional (FR-ONB-004): the API returns `null` until the
// owner enters one and never stores a placeholder. Models keep that raw value;
// every user-facing reference resolves the fallback here, in the viewer's
// locale. Names are shown exactly as entered (never prefixed, so
// "Baby Parker" stays "Baby Parker").

/// The baby's name standing on its own: titles, list rows, chips, and the
/// subject of a sentence ("{name} is here!"). Unnamed babies read as "Baby".
String babyNameLabel(AppLocalizations l10n, String? name) {
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? l10n.babyNameDefault : trimmed;
}

/// The baby referred to inside an owner-facing sentence ("Waiting for
/// {name}", "{actor} joined {baby}"). Unnamed babies read as "your baby".
String babyDisplayName(AppLocalizations l10n, String? name) {
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? l10n.babyNameFallback : trimmed;
}
