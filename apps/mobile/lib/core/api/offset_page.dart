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

/// Largest page the API accepts (`limit` max on every list endpoint).
const int maxOffsetPageLimit = 100;

/// Fetches every page of an offset-paginated collection.
///
/// [fetchPage] receives `limit` and `offset` and returns the decoded envelope.
/// Used for collections the UI needs whole (babies, members, registry).
Future<List<T>> fetchAllOffsetPages<T>(
  Future<Map<String, dynamic>> Function(int limit, int offset) fetchPage,
  T Function(Map<String, dynamic> row) mapItem, {
  int pageSize = maxOffsetPageLimit,
}) async {
  final all = <T>[];
  var offset = 0;
  while (true) {
    final page = parseOffsetPage(
      await fetchPage(pageSize, offset),
      mapItem,
      defaultLimit: pageSize,
    );
    all.addAll(page.items);
    if (!page.hasMore || page.items.isEmpty) return all;
    offset += page.items.length;
  }
}
