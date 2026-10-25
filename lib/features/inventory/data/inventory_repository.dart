import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/inventory_item.dart';

class InventoryRepository {
  InventoryRepository({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> _getCurrentShopId() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw InventoryRepositoryException(
        'Please sign in to access inventory.',
      );
    }

    try {
      final shop = await _client
          .from('shops')
          .select('id')
          .eq('owner_id', user.id)
          .eq('is_active', true)
          .maybeSingle();

      if (shop == null) {
        throw InventoryRepositoryException(
          'No active shop was found for this account.',
        );
      }

      return shop['id'] as String;
    } on InventoryRepositoryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw InventoryRepositoryException(
        'Could not identify your shop: ${error.message}',
      );
    }
  }

  Future<List<InventoryItem>> getInventory() async {
    try {
      final shopId = await _getCurrentShopId();

      // Load products belonging to the current shop.
      final productRows = await _client
          .from('products')
          .select(
            'id, shop_id, name, sku, unit, '
            'reorder_level, is_active',
          )
          .eq('shop_id', shopId)
          .eq('is_active', true)
          .order('name');

      // Load their inventory records separately.
      final inventoryRows = await _client
          .from('inventory')
          .select(
            'product_id, quantity, updated_at',
          )
          .eq('shop_id', shopId);

      final stockByProduct = <String, Map<String, dynamic>>{
        for (final row in inventoryRows)
          row['product_id'] as String: row,
      };

      return productRows.map((product) {
        final productId = product['id'] as String;

        return InventoryItem.fromRows(
          product: product,
          inventory: stockByProduct[productId],
        );
      }).toList();
    } on InventoryRepositoryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw InventoryRepositoryException(
        'Could not load inventory: ${error.message}',
      );
    }
  }

  Future<void> receiveStock({
    required String productId,
    required double quantity,
    String? reason,
    String? referenceId,
  }) async {
    try {
      final shopId = await _getCurrentShopId();

      await _client.rpc(
        'receive_stock',
        params: {
          'p_shop_id': shopId,
          'p_product_id': productId,
          'p_quantity': quantity,
          'p_reason': reason,
          'p_reference_id': referenceId,
        },
      );
    } on InventoryRepositoryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw InventoryRepositoryException(
        'Could not receive stock: ${error.message}',
      );
    }
  }

  Future<void> adjustStock({
    required String productId,
    required String movementType,
    required double quantity,
    required String reason,
    String? referenceId,
  }) async {
    try {
      final shopId = await _getCurrentShopId();

      await _client.rpc(
        'adjust_stock',
        params: {
          'p_shop_id': shopId,
          'p_product_id': productId,
          'p_movement_type': movementType,
          'p_quantity': quantity,
          'p_reason': reason,
          'p_reference_id': referenceId,
        },
      );
    } on InventoryRepositoryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw InventoryRepositoryException(
        'Could not adjust stock: ${error.message}',
      );
    }
  }  
}

class InventoryRepositoryException implements Exception {
  const InventoryRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}