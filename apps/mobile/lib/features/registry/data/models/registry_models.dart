class RegistryPurchaseInfo {
  RegistryPurchaseInfo({
    required this.purchaserDisplayName,
    this.purchasedAt,
    this.purchasedByFirebaseUid,
  });

  final String purchaserDisplayName;
  final String? purchasedAt;
  final String? purchasedByFirebaseUid;

  factory RegistryPurchaseInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return RegistryPurchaseInfo(purchaserDisplayName: '');
    }
    return RegistryPurchaseInfo(
      purchaserDisplayName:
          json['purchaser_display_name'] as String? ?? 'Family member',
      purchasedAt: json['purchased_at'] as String?,
      purchasedByFirebaseUid: json['purchased_by_firebase_uid'] as String?,
    );
  }
}

class RegistryItem {
  RegistryItem({
    required this.id,
    required this.name,
    this.description,
    this.productUrl,
    required this.priority,
    required this.isPurchased,
    this.purchase,
    this.catalogSuggestionId,
  });

  final String id;
  final String name;
  final String? description;
  final String? productUrl;
  final int priority;
  final bool isPurchased;
  final RegistryPurchaseInfo? purchase;
  final String? catalogSuggestionId;

  factory RegistryItem.fromJson(Map<String, dynamic> json) {
    final purchaseJson = json['purchase'] as Map<String, dynamic>?;
    return RegistryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      productUrl: json['product_url'] as String?,
      priority: json['priority'] as int? ?? 3,
      catalogSuggestionId: json['catalog_suggestion_id'] as String?,
      isPurchased: json['is_purchased'] as bool? ?? false,
      purchase: purchaseJson != null
          ? RegistryPurchaseInfo.fromJson(purchaseJson)
          : null,
    );
  }
}
