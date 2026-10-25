class ShopCategory {
  const ShopCategory({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    this.description,
    this.productCount = 0,
  });

  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  /// Number of products assigned to this category.
  final int productCount;

  factory ShopCategory.fromMap(
    Map<String, dynamic> map,
  ) {
    return ShopCategory(
      id: map['id'].toString(),
      name: map['name'].toString(),
      description: map['description']?.toString(),
      isActive: map['is_active'] == true,
      createdAt: DateTime.parse(
        map['created_at'].toString(),
      ),
      productCount: _readInteger(
        map['product_count'] ?? 0,
      ),
    );
  }
}

/// A product displayed in the category assignment interface.
class CategoryProductOption {
  const CategoryProductOption({
    required this.id,
    required this.name,
    required this.isActive,
    required this.isAssigned,
    this.sku,
  });

  final String id;
  final String name;
  final String? sku;
  final bool isActive;
  final bool isAssigned;

  factory CategoryProductOption.fromMap(
    Map<String, dynamic> map,
  ) {
    return CategoryProductOption(
      id: map['id'].toString(),
      name: map['name'].toString(),
      sku: map['sku']?.toString(),
      isActive: map['is_active'] == true,
      isAssigned: map['is_assigned'] == true,
    );
  }
}

int _readInteger(dynamic value) {
  if (value is int) return value;

  if (value is num && value.isFinite) {
    return value.toInt();
  }

  return int.tryParse(
        value?.toString() ?? '',
      ) ??
      0;
}