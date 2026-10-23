import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/catalog/suggestion_availability.dart';

void main() {
  test('normalizeCatalogMatchKey is case and whitespace insensitive', () {
    expect(
      normalizeCatalogMatchKey('  Gender   Reveal '),
      normalizeCatalogMatchKey('gender reveal'),
    );
  });

  test('claimedCatalogIdsWithTitleFallback matches titles when id is missing', () {
    final claimed = claimedCatalogIdsWithTitleFallback<
        ({String id, String title}),
        ({String? catalogId, String title})>(
      catalog: [
        (id: 'gender_reveal', title: 'Gender reveal'),
        (id: 'baby_shower', title: 'Baby shower'),
      ],
      existing: [
        (catalogId: null, title: 'Gender Reveal'),
      ],
      catalogIdForExisting: (e) => e.catalogId,
      titleForExisting: (e) => e.title,
      idForCatalog: (c) => c.id,
      titleForCatalog: (c) => c.title,
    );

    expect(claimed, {'gender_reveal'});
  });
}
