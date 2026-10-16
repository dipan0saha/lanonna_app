import 'package:lanonna/l10n/app_localizations.dart';

import '../data/models/registry_models.dart';

enum RegistryItemSort {
  priorityHighFirst,
  priorityLowFirst,
}

extension RegistryItemSortLabels on RegistryItemSort {
  String menuLabel(AppLocalizations l10n) => switch (this) {
        RegistryItemSort.priorityHighFirst => l10n.registrySortPriorityHighFirst,
        RegistryItemSort.priorityLowFirst => l10n.registrySortPriorityLowFirst,
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
