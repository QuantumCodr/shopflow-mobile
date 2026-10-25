import 'package:supabase_flutter/supabase_flutter.dart';

class SalesHistoryRepositoryException implements Exception {
  const SalesHistoryRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SalesHistoryRepository {
  SalesHistoryRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _saleColumns =
      'id, sale_number, status, subtotal_minor, '
      'discount_minor, total_minor, amount_paid_minor, '
      'change_minor, payment_method, created_at';

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
    } on SalesHistoryRepositoryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw SalesHistoryRepositoryException(
        'Could not identify the active shop: ${error.message}',
      );
    }
  }

  /// Retrieves the most recent sales, including their statuses.
  ///
  /// Results are ordered from newest to oldest.
  Future<List<Map<String, dynamic>>> getRecentSales({int limit = 100}) async {
    final shopId = await _requireActiveShopId();

    try {
      final response = await _client
          .from('sales')
          .select(_saleColumns)
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit);

      return response
          .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw SalesHistoryRepositoryException(
        'Could not load sales history: ${error.message}',
      );
    }
  }

  /// Retrieves the most recent completed sales.
  ///
  /// Used by the dashboard's recent-sales section.
  Future<List<Map<String, dynamic>>> getRecentCompletedSales({
    int limit = 5,
  }) async {
    if (limit < 1 || limit > 100) {
      throw const SalesHistoryRepositoryException(
        'The sales limit must be between 1 and 100.',
      );
    }

    final shopId = await _requireActiveShopId();

    try {
      final response = await _client
          .from('sales')
          .select(_saleColumns)
          .eq('shop_id', shopId)
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit);

      return response
          .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw SalesHistoryRepositoryException(
        'Could not load recent completed sales: ${error.message}',
      );
    }
  }

  /// Retrieves every completed sale within a date range.
  ///
  /// The start is inclusive and the end is exclusive.
  /// Pagination prevents the dashboard from relying on a single
  /// limited response when calculating today's sales.
  Future<List<Map<String, dynamic>>> getCompletedSalesBetween({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    if (!endExclusive.isAfter(startInclusive)) {
      throw const SalesHistoryRepositoryException(
        'The sales date range is invalid.',
      );
    }

    final shopId = await _requireActiveShopId();

    final startUtc = startInclusive.toUtc().toIso8601String();
    final endUtc = endExclusive.toUtc().toIso8601String();

    const pageSize = 500;
    var offset = 0;

    final sales = <Map<String, dynamic>>[];

    try {
      while (true) {
        final response = await _client
            .from('sales')
            .select(_saleColumns)
            .eq('shop_id', shopId)
            .eq('status', 'completed')
            .gte('created_at', startUtc)
            .lt('created_at', endUtc)
            .order('created_at', ascending: false)
            .order('id', ascending: false)
            .range(offset, offset + pageSize - 1);

        final page = response
            .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);

        sales.addAll(page);

        if (page.length < pageSize) {
          break;
        }

        offset += pageSize;
      }

      return sales;
    } on PostgrestException catch (error) {
      throw SalesHistoryRepositoryException(
        'Could not load sales for the selected period: '
        '${error.message}',
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
          .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw SalesHistoryRepositoryException(
        'Could not load the items for this sale: ${error.message}',
      );
    }
  }
}
