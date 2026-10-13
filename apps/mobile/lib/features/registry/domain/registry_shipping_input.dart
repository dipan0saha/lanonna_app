import '../../../core/input/person_name_input.dart';

/// Normalizes state/province for registry shipping: title-case, then uppercase
/// 1–3 letter all-alpha codes (e.g. NC, ON).
String formatRegistryShippingRegion(String raw) {
  final titled = formatPersonName(raw);
  if (titled.isEmpty) return '';
  if (titled.length <= 3 && RegExp(r'^[A-Za-z]+$').hasMatch(titled)) {
    return titled.toUpperCase();
  }
  return titled;
}
