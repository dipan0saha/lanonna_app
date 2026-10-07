abstract final class RegistryRoutes {
  static const registry = '/registry';
  static const createItem = '/registry/item/create';
  static const aiSuggestions = '/registry/ai-suggestions';
  static const shippingAddress = '/registry/shipping-address';

  static String itemEdit(String itemId) => '/registry/item/$itemId/edit';
}
