import 'package:supabase_flutter/supabase_flutter.dart';

class PosRepositoryException implements Exception {
  const PosRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PosRepository {
  PosRepository({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Loads inventory quantities visible to the authenticated user.
  ///
  /// Supabase RLS must restrict the returned rows to authorised stock.
  Future<Map<String, int>> getStockLevels() async {
    final response = await _client
        .from('inventory')
        .select('product_id, quantity');

    final result = <String, int>{};

    for (final row in response) {
      final productId = row['product_id']?.toString();

      if (productId == null) continue;

      final dynamic rawQuantity = row['quantity'];

      final int quantity;
      if (rawQuantity is int) {
        quantity = rawQuantity;
      } else if (rawQuantity is num) {
        quantity = rawQuantity.toInt();
      } else {
        quantity = int.tryParse(
              rawQuantity?.toString() ?? '',
            ) ??
            0;
      }

      result[productId] = quantity;
    }

    return result;
  }

  /// Records a sale through one PostgreSQL transaction.
  ///
  /// The database function must recalculate prices and validate stock.
  /// Do not trust prices or quantities submitted by the client alone.
  Future<Map<String, dynamic>> completeSale({
    required List<Map<String, dynamic>> items,
    required int paymentAmount,
  }) async {
    final response = await _client.rpc(
      'complete_sale',
      params: {
        'p_items': items,
        'p_payment': paymentAmount,
      },
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw const PosRepositoryException(
      'The sale was submitted, but the server returned '
      'an unexpected response.',
    );
  }
}