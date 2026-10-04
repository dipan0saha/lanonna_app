import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/registry/data/models/registry_models.dart';
import 'package:lanonna/features/registry/data/registry_suggestions_catalog.dart';
import 'package:lanonna/features/registry/domain/registry_suggestion_availability.dart';

void main() {
  test('availableSuggestions excludes claimed catalog ids', () {
    final catalog = [
      RegistrySuggestion(
        id: 'swaddle_blankets',
        name: 'Swaddle Blankets',
        description: 'A',
      ),
      RegistrySuggestion(
        id: 'diaper_pail',
        name: 'Diaper Pail',
        description: 'B',
      ),
    ];
    final items = [
      RegistryItem(
        id: '1',
        name: 'Swaddle Blankets',
        priority: 3,
        isPurchased: false,
        catalogSuggestionId: 'swaddle_blankets',
      ),
    ];

    final available = availableSuggestions(catalog, items);

    expect(available.map((s) => s.id), ['diaper_pail']);
  });

  test('claimedCatalogSuggestionIds ignores null ids', () {
    final items = [
      RegistryItem(
        id: '1',
        name: 'Manual item',
        priority: 3,
        isPurchased: false,
      ),
      RegistryItem(
        id: '2',
        name: 'From catalog',
        priority: 3,
        isPurchased: true,
        catalogSuggestionId: 'high_chair',
      ),
    ];

    expect(claimedCatalogSuggestionIds(items), {'high_chair'});
  });
}
