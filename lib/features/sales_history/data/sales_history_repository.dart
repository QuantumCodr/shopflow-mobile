import 'package:supabase_flutter/supabase_flutter.dart';

class SalesHistoryRepositoryException implements Exception {
  const SalesHistoryRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SalesHistoryRepository {
  SalesHistoryRepository({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> _requireActiveShopId() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw const SalesHistoryRepositoryException(
        'Please sign in to view sales history.',
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
        throw const SalesHistoryRepositoryException(
          'No active shop was found for this account.',
        );
      }

      final shopId = response['id']?.toString();

      if (shopId == null || shopId.isEmpty) {
        throw const SalesHistoryRepositoryException(
          'The active shop has an invalid ID.',
        );
      }

      return shopId;
    } on PostgrestException catch (error) {
      throw SalesHistoryRepositoryException(
        'Could not identify the active shop: ${error.message}',
      );
    }
  }

  /// Retrieves the most recent 100 sales.
  ///
  /// The result is ordered from newest to oldest.
  Future<List<Map<String, dynamic>>> getRecentSales({
    int limit = 100,
  }) async {
    final shopId = await _requireActiveShopId();

    try {
      final response = await _client
          .from('sales')
          .select(
            'id, sale_number, status, subtotal_minor, '
            'discount_minor, total_minor, amount_paid_minor, '
            'change_minor, payment_method, created_at',
          )
          .eq('shop_id', shopId)
          .order(
            'created_at',
            ascending: false,
          )
          .limit(limit);

      return response
          .map<Map<String, dynamic>>(
            (row) => Map<String, dynamic>.from(row),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw SalesHistoryRepositoryException(
        'Could not load sales history: ${error.message}',
      );
    }
  }

  /// Retrieves the recorded line items for one sale.
  ///
  /// Both the sale and its items belong to the active shop.
  Future<List<Map<String, dynamic>>> getSaleItems({
    required String saleId,
  }) async {
    final shopId = await _requireActiveShopId();

    try {
      final response = await _client
          .from('sale_items')
          .select(
            'id, sale_id, product_id, product_name, '
            'quantity, unit_price_minor, unit_cost_minor, '
            'line_total_minor',
          )
          .eq('shop_id', shopId)
          .eq('sale_id', saleId);

      return response
          .map<Map<String, dynamic>>(
            (row) => Map<String, dynamic>.from(row),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw SalesHistoryRepositoryException(
        'Could not load the items for this sale: ${error.message}',
      );
    }
  }
}