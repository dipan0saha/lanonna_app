import '../../../core/api/api_client.dart';
import '../../../core/api/offset_page.dart';
import 'models/registry_models.dart';

class RegistryRepository {
  RegistryRepository(this._api);

  final ApiClient _api;

  Future<List<RegistryItem>> listItems(String babyId) async {
    const pageSize = 100;
    final all = <RegistryItem>[];
    var offset = 0;
    while (true) {
      final json = await _api.getJson(
        '/v1/babies/$babyId/registry/items?limit=$pageSize&offset=$offset',
      );
      final page = parseOffsetPage(
        json,
        RegistryItem.fromJson,
        defaultLimit: pageSize,
      );
      all.addAll(page.items);
      if (!page.hasMore) break;
      offset += page.items.length;
    }
    return all;
  }

  Future<RegistryItem> createItem(
    String babyId, {
    required String name,
    String? description,
    String? productUrl,
    required int priority,
    String? catalogSuggestionId,
  }) async {
    final json = await _api.postJson('/v1/babies/$babyId/registry/items', body: {
      'name': name,
      if (description != null) 'description': description,
      if (productUrl != null) 'product_url': productUrl,
      'priority': priority,
      if (catalogSuggestionId != null)
        'catalog_suggestion_id': catalogSuggestionId,
    });
    return RegistryItem.fromJson(json);
  }

  Future<RegistryItem> updateItem(
    String babyId,
    String itemId, {
    String? name,
    String? description,
    String? productUrl,
    int? priority,
  }) async {
    final json = await _api.patchJson(
      '/v1/babies/$babyId/registry/items/$itemId',
      body: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (productUrl != null) 'product_url': productUrl,
        if (priority != null) 'priority': priority,
      },
    );
    return RegistryItem.fromJson(json);
  }

  Future<void> deleteItem(String babyId, String itemId) async {
    await _api.deleteJson('/v1/babies/$babyId/registry/items/$itemId');
  }

  Future<void> claimPurchase(String babyId, String itemId) async {
    await _api.postJson('/v1/babies/$babyId/registry/items/$itemId/purchase');
  }

  Future<void> undoPurchase(String babyId, String itemId) async {
    await _api.deleteJson('/v1/babies/$babyId/registry/items/$itemId/purchase');
  }

  Future<RegistryShippingAddress> getShippingAddress(String babyId) async {
    final json =
        await _api.getJson('/v1/babies/$babyId/registry/shipping-address');
    return RegistryShippingAddress.fromJson(json);
  }

  Future<RegistryShippingAddress> updateShippingAddress(
    String babyId,
    Map<String, dynamic> body,
  ) async {
    final json = await _api.patchJson(
      '/v1/babies/$babyId/registry/shipping-address',
      body: body,
    );
    return RegistryShippingAddress.fromJson(json);
  }
}
