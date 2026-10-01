import '../../../core/api/api_client.dart';
import 'models/registry_models.dart';

class RegistryRepository {
  RegistryRepository(this._api);

  final ApiClient _api;

  Future<List<RegistryItem>> listItems(String babyId) async {
    final list = await _api.getJsonList('/v1/babies/$babyId/registry/items');
    return list
        .whereType<Map<String, dynamic>>()
        .map(RegistryItem.fromJson)
        .toList();
  }

  Future<RegistryItem> createItem(
    String babyId, {
    required String name,
    String? description,
    String? productUrl,
    required int priority,
  }) async {
    final json = await _api.postJson('/v1/babies/$babyId/registry/items', body: {
      'name': name,
      if (description != null) 'description': description,
      if (productUrl != null) 'product_url': productUrl,
      'priority': priority,
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

  Future<String?> getShippingAddress(String babyId) async {
    final json =
        await _api.getJson('/v1/babies/$babyId/registry/shipping-address');
    return json['address'] as String?;
  }

  Future<void> updateShippingAddress(String babyId, String? address) async {
    await _api.patchJson('/v1/babies/$babyId/registry/shipping-address', body: {
      'address': address,
    });
  }
}
