import '../data/product_repository.dart';
import '../models/product.dart';

class ProductValidationException implements Exception {
  const ProductValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductService {
  ProductService({
    ProductRepository? repository,
  }) : _repository = repository ?? ProductRepository();

  final ProductRepository _repository;

  static const List<String> units = [
    'piece',
    'kg',
    'g',
    'litre',
    'ml',
    'pack',
    'box',
    'bottle',
    'dozen',
  ];

  Future<List<Product>> getActiveProducts() {
    return _repository.getActiveProducts();
  }

  /// Validates and creates or updates a product.
  Future<Product> saveProduct({
    String? id,
    required String name,
    String? sku,
    required String unit,
    required int costPrice,
    required int sellingPrice,
    required int reorderLevel,
  }) async {
    final normalizedName = name.trim();
    final normalizedSku = sku?.trim().toUpperCase();
    final normalizedUnit = unit.trim().toLowerCase();

    if (normalizedName.isEmpty) {
      throw const ProductValidationException(
        'Please enter a product name.',
      );
    }

    if (normalizedName.length > 150) {
      throw const ProductValidationException(
        'Product names must be 150 characters or fewer.',
      );
    }

    if (normalizedSku != null &&
        normalizedSku.isNotEmpty &&
        normalizedSku.length > 50) {
      throw const ProductValidationException(
        'SKU must be 50 characters or fewer.',
      );
    }

    if (!units.contains(normalizedUnit)) {
      throw const ProductValidationException(
        'Please select a valid unit.',
      );
    }

    if (costPrice < 0 || sellingPrice < 0) {
      throw const ProductValidationException(
        'Prices cannot be negative.',
      );
    }

    if (reorderLevel < 0) {
      throw const ProductValidationException(
        'The reorder level cannot be negative.',
      );
    }

    final product = Product(
      id: id ?? '',
      name: normalizedName,
      sku: normalizedSku == null || normalizedSku.isEmpty
          ? null
          : normalizedSku,
      unit: normalizedUnit,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      reorderLevel: reorderLevel,
      active: true,
    );

    if (id == null) {
      return _repository.createProduct(product);
    }

    return _repository.updateProduct(product);
  }

  Future<void> deactivateProduct(String productId) {
    if (productId.trim().isEmpty) {
      throw const ProductValidationException(
        'A valid product must be selected.',
      );
    }

    return _repository.deactivateProduct(productId);
  }
}