Set<String> claimedIdsFromNullable(Iterable<String?> ids) =>
    ids.whereType<String>().toSet();

/// Case- and whitespace-insensitive key for matching catalog titles to saved rows.
String normalizeCatalogMatchKey(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Catalog ids claimed by [existing], using explicit ids plus [titleForExisting]
/// matched against [catalog] titles when no id is stored.
Set<String> claimedCatalogIdsWithTitleFallback<TCatalog, TExisting>({
  required List<TCatalog> catalog,
  required Iterable<TExisting> existing,
  required String? Function(TExisting) catalogIdForExisting,
  required String Function(TExisting) titleForExisting,
  required String Function(TCatalog) idForCatalog,
  required String Function(TCatalog) titleForCatalog,
}) {
  final claimed = claimedIdsFromNullable(
    existing.map(catalogIdForExisting),
  );
  final titleToId = <String, String>{
    for (final row in catalog)
      normalizeCatalogMatchKey(titleForCatalog(row)): idForCatalog(row),
  };
  for (final row in existing) {
    if (catalogIdForExisting(row) != null) continue;
    final id = titleToId[normalizeCatalogMatchKey(titleForExisting(row))];
    if (id != null) claimed.add(id);
  }
  return claimed;
}

List<T> excludingClaimedIds<T>({
  required List<T> catalog,
  required Set<String> claimedIds,
  required String Function(T) idFor,
}) => catalog.where((item) => !claimedIds.contains(idFor(item))).toList();
