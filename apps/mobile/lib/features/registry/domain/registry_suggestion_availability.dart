import '../../../core/catalog/suggestion_availability.dart';
import '../data/models/registry_models.dart';
import '../data/registry_suggestions_catalog.dart';

Set<String> claimedCatalogSuggestionIds(Iterable<RegistryItem> items) =>
    claimedIdsFromNullable(items.map((i) => i.catalogSuggestionId));

List<RegistrySuggestion> availableSuggestions(
  List<RegistrySuggestion> catalog,
  Iterable<RegistryItem> items,
) {
  final claimed = claimedCatalogSuggestionIds(items);
  return excludingClaimedIds(
    catalog: catalog,
    claimedIds: claimed,
    idFor: (s) => s.id,
  );
}
