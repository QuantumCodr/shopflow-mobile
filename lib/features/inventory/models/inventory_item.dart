class InventoryItem {
  const InventoryItem({
    required this.productId,
    required this.shopId,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.reorderLevel,
    required this.isActive,
    this.sku,
    this.updatedAt,
  });

  final String productId;
  final String shopId;
  final String name;
  final String unit;

  final String? sku;

  /// Current available quantity.
  final double quantity;

  /// Threshold at which stock is considered low.
  final double reorderLevel;

  final bool isActive;
  final DateTime? updatedAt;

  bool get isOutOfStock => quantity <= 0;

  bool get isLowStock =>
      quantity > 0 && quantity <= reorderLevel;

  String get stockStatus {
    if (isOutOfStock) return 'Out of stock';
    if (isLowStock) return 'Low stock';
    return 'In stock';
  }

  factory InventoryItem.fromRows({
    required Map<String, dynamic> product,
    Map<String, dynamic>? inventory,
  }) {
    return InventoryItem(
      productId: product['id'] as String,
      shopId: product['shop_id'] as String,
      name: product['name'] as String,
      sku: product['sku'] as String?,
      unit: product['unit'] as String,
      quantity: _asDouble(inventory?['quantity']),
      reorderLevel: _asDouble(product['reorder_level']),
      isActive: product['is_active'] as bool? ?? true,
      updatedAt: inventory?['updated_at'] == null
          ? null
          : DateTime.tryParse(
              inventory!['updated_at'].toString(),
            ),
    );
  }

  static double _asDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }
}