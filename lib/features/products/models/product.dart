class Product {
  const Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.costPrice,
    required this.sellingPrice,
    required this.reorderLevel,
    required this.active,
    this.sku,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? sku;
  final String unit;

  /// Monetary amounts are stored in minor currency units.
  ///
  /// For example, 1250 represents SLE 12.50.
  final int costPrice;
  final int sellingPrice;

  final int reorderLevel;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'].toString(),
      name: map['name'] as String,
      sku: map['sku'] as String?,
      unit: map['unit']?.toString() ?? 'piece',
      costPrice: _asInt(map['cost_price_minor']),
      sellingPrice: _asInt(map['selling_price_minor']),
      reorderLevel: _asInt(map['reorder_level']),
      active: map['is_active'] as bool? ?? true,
      createdAt: _asDateTime(map['created_at']),
      updatedAt: _asDateTime(map['updated_at']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;

    return DateTime.tryParse(value.toString());
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'name': name,
      'sku': sku,
      'unit': unit,
      'cost_price_minor': costPrice,
      'selling_price_minor': sellingPrice,
      'reorder_level': reorderLevel,
      'is_active': active,
    };
  }
}