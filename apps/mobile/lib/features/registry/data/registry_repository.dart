import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/offset_page.dart';
import 'models/registry_models.dart';

/// Registry items and shipping address for a baby.
///
/// Notifies listeners after every successful mutation, so any screen showing
/// registry data (the Registry tab, AI suggestions) reloads no matter which
/// screen made the change. Screens do not pass "changed" results back through
/// route pops.
class RegistryRepository extends ChangeNotifier {
  RegistryRepository(this._api);

  final ApiClient _api;

  Future<List<RegistryItem>> listItems(String babyId) {
    return fetchAllOffsetPages(
      (limit, offset) => _api.getJson(
        '/v1/babies/$babyId/registry/items?limit=$limit&offset=$offset',
      ),
      RegistryItem.fromJson,
    );
  }

  Future<RegistryItem> createItem(
    String babyId, {
    required String name,
    String? description,
    String? productUrl,
    required int priority,
    String? catalogSuggestionId,
  }) async {
    final json = await _api.postJson(
      '/v1/babies/$babyId/registry/items',
      body: {
        'name': name,
        if (description != null) 'description': description,
        if (productUrl != null) 'product_url': productUrl,
        'priority': priority,
        if (catalogSuggestionId != null)
          'catalog_suggestion_id': catalogSuggestionId,
      },
    );
    notifyListeners();
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
    notifyListeners();
    return RegistryItem.fromJson(json);
  }

  Future<void> deleteItem(String babyId, String itemId) async {
    await _api.deleteJson('/v1/babies/$babyId/registry/items/$itemId');
    notifyListeners();
  }

  Future<void> claimPurchase(String babyId, String itemId) async {
    await _api.postJson('/v1/babies/$babyId/registry/items/$itemId/purchase');
    notifyListeners();
  }

  Future<void> undoPurchase(String babyId, String itemId) async {
    await _api.deleteJson('/v1/babies/$babyId/registry/items/$itemId/purchase');
    notifyListeners();
  }

  Future<RegistryShippingAddress> getShippingAddress(String babyId) async {
    final json = await _api.getJson(
      '/v1/babies/$babyId/registry/shipping-address',
    );
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
    notifyListeners();
    return RegistryShippingAddress.fromJson(json);
  }
}
