import '../json/json_readers.dart';

/// Keyset-pagination envelope from the API (`items`, `has_more`, `next_cursor`).
class CursorPage<T> {
  CursorPage({
    required this.items,
    required this.hasMore,
    required this.limit,
    this.nextCursor,
  });

  final List<T> items;
  final bool hasMore;
  final int limit;
  final String? nextCursor;
}

CursorPage<T> parseCursorPage<T>(
  Map<String, dynamic> json,
  T Function(Map<String, dynamic> row) mapItem, {
  int defaultLimit = 50,
}) {
  final rawItems = json['items'] as List<dynamic>? ?? [];
  final items = rawItems
      .whereType<Map<String, dynamic>>()
      .map(mapItem)
      .toList();
  return CursorPage(
    items: items,
    hasMore: json['has_more'] as bool? ?? false,
    limit: readInt(json['limit'], defaultValue: defaultLimit),
    nextCursor: json['next_cursor'] as String?,
  );
}
