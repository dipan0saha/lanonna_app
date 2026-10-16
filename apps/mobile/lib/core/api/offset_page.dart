import '../json/json_readers.dart';

/// Shared offset-pagination envelope from the API (`items`, `has_more`, …).
class OffsetPage<T> {
  OffsetPage({
    required this.items,
    required this.hasMore,
    required this.offset,
    required this.limit,
  });

  final List<T> items;
  final bool hasMore;
  final int offset;
  final int limit;
}

OffsetPage<T> parseOffsetPage<T>(
  Map<String, dynamic> json,
  T Function(Map<String, dynamic> row) mapItem, {
  int defaultLimit = 50,
}) {
  final rawItems = json['items'] as List<dynamic>? ?? [];
  final items = rawItems
      .whereType<Map<String, dynamic>>()
      .map(mapItem)
      .toList();
  return OffsetPage(
    items: items,
    hasMore: json['has_more'] as bool? ?? false,
    offset: readInt(json['offset']),
    limit: readInt(json['limit'], defaultValue: defaultLimit),
  );
}
