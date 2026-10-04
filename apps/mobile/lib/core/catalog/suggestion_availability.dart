Set<String> claimedIdsFromNullable(Iterable<String?> ids) =>
    ids.whereType<String>().toSet();

List<T> excludingClaimedIds<T>({
  required List<T> catalog,
  required Set<String> claimedIds,
  required String Function(T) idFor,
}) => catalog.where((item) => !claimedIds.contains(idFor(item))).toList();
