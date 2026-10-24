import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';

class ProductRepositoryException implements Exception {
  const ProductRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductRepository {
  ProductRepository({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _table = 'products';

  static const String _columns =
      'id, shop_id, name, sku, unit, '
      'cost_price_minor, selling_price_minor, '
      'reorder_level, is_active, created_at, updated_at';

  /// Finds the shop owned by the authenticated user.
  Future<String> _getCurrentShopId() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw const ProductRepositoryException(
        'You must be signed in to manage products.',
      );
    }

    final shop = await _client
        .from('shops')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();

    if (shop == null) {
      throw const ProductRepositoryException(
        'No shop was found for your account. '
        'Please complete shop setup first.',
      );
    }

    return shop['id'].toString();
  }

  /// Loads active products belonging to the current shop.
  Future<List<Product>> getActiveProducts() async {
    final shopId = await _getCurrentShopId();

    try {
      final response = await _client
          .from(_table)
          .select(_columns)
          .eq('shop_id', shopId)
          .eq('is_active', true)
          .order('name', ascending: true);

      return (response as List<dynamic>)
          .map(
            (row) => Product.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
    } on PostgrestException catch (error) {
      throw ProductRepositoryException(
        'Could not load products: ${error.message}',
      );
    }
  }

  /// Creates a product for the current shop.
  Future<Product> createProduct(Product product) async {
    final shopId = await _getCurrentShopId();

    try {
      final response = await _client
          .from(_table)
          .insert({
            ...product.toInsertMap(),
            'shop_id': shopId,
          })
          .select(_columns)
          .single();

      return Product.fromMap(response);
    } on PostgrestException catch (error) {
      throw ProductRepositoryException(
        'Could not create the product: ${error.message}',
      );
    }
  }

  /// Updates a product belonging to the current shop.
  Future<Product> updateProduct(Product product) async {
    final shopId = await _getCurrentShopId();

    try {
      final response = await _client
          .from(_table)
          .update({
            ...product.toInsertMap(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', product.id)
          .eq('shop_id', shopId)
          .select(_columns)
          .maybeSingle();

      if (response == null) {
        throw const ProductRepositoryException(
          'The product could not be updated. '
          'Check that it exists and you have permission to edit it.',
        );
      }

      return Product.fromMap(response);
    } on PostgrestException catch (error) {
      throw ProductRepositoryException(
        'Could not update the product: ${error.message}',
      );
    }
  }

  /// Deactivates a product instead of permanently deleting it.
  Future<void> deactivateProduct(String productId) async {
    final shopId = await _getCurrentShopId();

    try {
      final response = await _client
          .from(_table)
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', productId)
          .eq('shop_id', shopId)
          .select('id')
          .maybeSingle();

      if (response == null) {
        throw const ProductRepositoryException(
          'The product could not be deactivated.',
        );
      }
    } on PostgrestException catch (error) {
      throw ProductRepositoryException(
        'Could not deactivate the product: ${error.message}',
      );
    }
  }
}