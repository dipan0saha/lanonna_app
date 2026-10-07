class RegistryShippingAddress {
  const RegistryShippingAddress({
    this.line1,
    this.line2,
    this.city,
    this.region,
    this.postalCode,
    this.countryCode,
    this.formatted,
  });

  final String? line1;
  final String? line2;
  final String? city;
  final String? region;
  final String? postalCode;
  final String? countryCode;
  final String? formatted;

  bool get isEmpty =>
      (line1 == null || line1!.isEmpty) &&
      (line2 == null || line2!.isEmpty) &&
      (city == null || city!.isEmpty) &&
      (region == null || region!.isEmpty) &&
      (postalCode == null || postalCode!.isEmpty) &&
      (countryCode == null || countryCode!.isEmpty);

  factory RegistryShippingAddress.fromJson(Map<String, dynamic> json) {
    return RegistryShippingAddress(
      line1: json['line1'] as String?,
      line2: json['line2'] as String?,
      city: json['city'] as String?,
      region: json['region'] as String?,
      postalCode: json['postal_code'] as String?,
      countryCode: json['country_code'] as String?,
      formatted: json['formatted'] as String?,
    );
  }

  Map<String, dynamic> toPatchJson() => {
        'line1': _emptyToNull(line1),
        'line2': _emptyToNull(line2),
        'city': _emptyToNull(city),
        'region': _emptyToNull(region),
        'postal_code': _emptyToNull(postalCode),
        'country_code': _emptyToNull(countryCode),
      };

  static Map<String, dynamic> clearPatchJson() => {
        'line1': null,
        'line2': null,
        'city': null,
        'region': null,
        'postal_code': null,
        'country_code': null,
      };

  static String? _emptyToNull(String? value) {
    if (value == null) return null;
    final t = value.trim();
    return t.isEmpty ? null : t;
  }
}

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
