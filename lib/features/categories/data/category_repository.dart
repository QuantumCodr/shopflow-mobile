import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryRepositoryException implements Exception {
  const CategoryRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CategoryRepository {
  CategoryRepository({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // =========================================================
  // ACTIVE SHOP
  // =========================================================

  Future<String> _requireActiveShopId() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw const CategoryRepositoryException(
        'Please sign in to manage categories.',
      );
    }

    try {
      final response = await _client
          .from('shops')
          .select('id')
          .eq('owner_id', user.id)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        throw const CategoryRepositoryException(
          'No active shop was found for this account.',
        );
      }

      final shopId = response['id']?.toString();

      if (shopId == null || shopId.isEmpty) {
        throw const CategoryRepositoryException(
          'The active shop has an invalid ID.',
        );
      }

      return shopId;
    } on PostgrestException catch (error) {
      throw CategoryRepositoryException(
        'Could not identify the active shop: ${error.message}',
      );
    }
  }

  // =========================================================
  // READ CATEGORIES
  // =========================================================

  Future<List<Map<String, dynamic>>> getCategories() async {
    final shopId = await _requireActiveShopId();

    try {
      final categoryResponse = await _client
          .from('categories')
          .select(
            'id, name, description, is_active, created_at',
          )
          .eq('shop_id', shopId)
          .order('name', ascending: true);

      final categories = categoryResponse
          .map<Map<String, dynamic>>(
            (row) => Map<String, dynamic>.from(row),
          )
          .toList(growable: false);

      if (categories.isEmpty) {
        return const [];
      }

      // Count category memberships without adding category_id
      // to the products table.
      final membershipResponse = await _client
          .from('product_categories')
          .select('category_id')
          .eq('shop_id', shopId);

      final productCounts = <String, int>{};

      for (final row in membershipResponse) {
        final categoryId = row['category_id']?.toString();

        if (categoryId == null) continue;

        productCounts.update(
          categoryId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }

      return categories.map((category) {
        final result = Map<String, dynamic>.from(category);

        result['product_count'] =
            productCounts[result['id'].toString()] ?? 0;

        return result;
      }).toList(growable: false);
    } on PostgrestException catch (error) {
      throw CategoryRepositoryException(
        'Could not load categories: ${error.message}',
      );
    }
  }

  // =========================================================
  // CREATE OR UPDATE CATEGORY
  // =========================================================

  Future<void> saveCategory({
    String? id,
    required String name,
    String? description,
  }) async {
    final shopId = await _requireActiveShopId();

    final cleanName = name.trim();
    final cleanDescription = description?.trim();

    if (cleanName.isEmpty) {
      throw const CategoryRepositoryException(
        'Category name cannot be empty.',
      );
    }

    if (cleanName.length > 80) {
      throw const CategoryRepositoryException(
        'Category names cannot exceed 80 characters.',
      );
    }

    final payload = <String, dynamic>{
      'name': cleanName,
      'description':
          cleanDescription == null ||
                  cleanDescription.isEmpty
              ? null
              : cleanDescription,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      if (id == null) {
        await _client.from('categories').insert({
          ...payload,
          'shop_id': shopId,
          'is_active': true,
        });
      } else {
        final response = await _client
            .from('categories')
            .update(payload)
            .eq('shop_id', shopId)
            .eq('id', id)
            .select('id');

        if (response.isEmpty) {
          throw const CategoryRepositoryException(
            'The category was not found or could not be updated.',
          );
        }
      }
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();

      if (message.contains('categories_shop_id_name_key') ||
          message.contains('duplicate key')) {
        throw const CategoryRepositoryException(
          'A category with this name already exists.',
        );
      }

      throw CategoryRepositoryException(
        'Could not save category: ${error.message}',
      );
    }
  }

  // =========================================================
  // ACTIVATE OR DEACTIVATE
  // =========================================================

  Future<void> setCategoryActive({
    required String categoryId,
    required bool isActive,
  }) async {
    final shopId = await _requireActiveShopId();

    try {
      final response = await _client
          .from('categories')
          .update({
            'is_active': isActive,
            'updated_at':
                DateTime.now().toUtc().toIso8601String(),
          })
          .eq('shop_id', shopId)
          .eq('id', categoryId)
          .select('id');

      if (response.isEmpty) {
        throw const CategoryRepositoryException(
          'The category could not be updated.',
        );
      }
    } on PostgrestException catch (error) {
      throw CategoryRepositoryException(
        'Could not update category status: ${error.message}',
      );
    }
  }

  // =========================================================
  // PRODUCT ASSIGNMENTS
  // =========================================================

  Future<List<Map<String, dynamic>>> getProductsForCategory({
    required String categoryId,
  }) async {
    final shopId = await _requireActiveShopId();

    try {
      final productsResponse = await _client
          .from('products')
          .select('id, name, sku, is_active')
          .eq('shop_id', shopId)
          .order('name', ascending: true);

      final membershipResponse = await _client
          .from('product_categories')
          .select('product_id')
          .eq('shop_id', shopId)
          .eq('category_id', categoryId);

      final assignedProductIds = membershipResponse
          .map((row) => row['product_id'].toString())
          .toSet();

      return productsResponse.map((row) {
        final product = Map<String, dynamic>.from(row);

        product['is_assigned'] =
            assignedProductIds.contains(
          product['id'].toString(),
        );

        return product;
      }).toList(growable: false);
    } on PostgrestException catch (error) {
      throw CategoryRepositoryException(
        'Could not load product assignments: ${error.message}',
      );
    }
  }

  /// Adds or removes one product/category relationship.
  ///
  /// This uses the existing many-to-many join table.
  Future<void> setProductAssigned({
    required String categoryId,
    required String productId,
    required bool isAssigned,
  }) async {
    final shopId = await _requireActiveShopId();

    try {
      if (isAssigned) {
        await _client.from('product_categories').upsert(
          {
            'shop_id': shopId,
            'category_id': categoryId,
            'product_id': productId,
          },
          onConflict: 'shop_id,product_id,category_id',
          ignoreDuplicates: true,
        );
      } else {
        await _client
            .from('product_categories')
            .delete()
            .eq('shop_id', shopId)
            .eq('category_id', categoryId)
            .eq('product_id', productId);
      }
    } on PostgrestException catch (error) {
      throw CategoryRepositoryException(
        'Could not update product assignment: ${error.message}',
      );
    }
  }
}