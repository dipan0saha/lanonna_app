import '../data/models/registry_models.dart';

enum RegistryItemSort {
  priorityHighFirst,
  priorityLowFirst,
}

extension RegistryItemSortLabels on RegistryItemSort {
  String get menuLabel => switch (this) {
        RegistryItemSort.priorityHighFirst => 'Priority: High first',
        RegistryItemSort.priorityLowFirst => 'Priority: Low first',
      };

  RegistryItemSort get toggled => switch (this) {
        RegistryItemSort.priorityHighFirst =>
          RegistryItemSort.priorityLowFirst,
        RegistryItemSort.priorityLowFirst =>
          RegistryItemSort.priorityHighFirst,
      };
}

List<RegistryItem> sortRegistryItems(
  List<RegistryItem> items,
  RegistryItemSort sort,
) {
  final copy = List<RegistryItem>.from(items);
  copy.sort((a, b) {
    final cmp = sort == RegistryItemSort.priorityHighFirst
        ? b.priority.compareTo(a.priority)
        : a.priority.compareTo(b.priority);
    if (cmp != 0) return cmp;
    return a.name.compareTo(b.name);
  });
  return copy;
}
