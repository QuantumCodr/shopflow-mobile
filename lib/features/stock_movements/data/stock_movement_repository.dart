import 'package:supabase_flutter/supabase_flutter.dart';

class StockMovementRepositoryException implements Exception {
  const StockMovementRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StockMovementRepository {
  StockMovementRepository({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> _requireActiveShopId() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw const StockMovementRepositoryException(
        'Please sign in to view stock history.',
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
        throw const StockMovementRepositoryException(
          'No active shop was found for this account.',
        );
      }

      final shopId = response['id']?.toString();

      if (shopId == null || shopId.isEmpty) {
        throw const StockMovementRepositoryException(
          'The active shop has an invalid ID.',
        );
      }

      return shopId;
    } on PostgrestException catch (error) {
      throw StockMovementRepositoryException(
        'Could not identify the active shop: ${error.message}',
      );
    }
  }

  /// Loads the 200 most recent stock movements.
  ///
  /// Product names and units are retrieved separately so historical
  /// movements remain visible without depending on a nested relation.
  Future<List<Map<String, dynamic>>> getRecentMovements({
    int limit = 200,
  }) async {
    final shopId = await _requireActiveShopId();

    try {
      final response = await _client
          .from('stock_movements')
          .select(
            'id, product_id, movement_type, quantity_delta, '
            'reason, reference_id, created_at',
          )
          .eq('shop_id', shopId)
          .order(
            'created_at',
            ascending: false,
          )
          .limit(limit);

      final movementRows = response
          .map<Map<String, dynamic>>(
            (row) => Map<String, dynamic>.from(row),
          )
          .toList(growable: false);

      if (movementRows.isEmpty) {
        return const [];
      }

      final productIds = movementRows
          .map((row) => row['product_id'].toString())
          .toSet()
          .toList(growable: false);

      final products = await _client
          .from('products')
          .select('id, name, unit')
          .eq('shop_id', shopId)
          .inFilter('id', productIds);

      final productById = <String, Map<String, dynamic>>{
        for (final product in products)
          product['id'].toString():
              Map<String, dynamic>.from(product),
      };

      return movementRows.map((row) {
        final productId = row['product_id'].toString();
        final product = productById[productId];

        return <String, dynamic>{
          ...row,
          'product_name':
              product?['name']?.toString() ?? 'Unknown product',
          'product_unit':
              product?['unit']?.toString() ?? 'piece',
        };
      }).toList(growable: false);
    } on PostgrestException catch (error) {
      throw StockMovementRepositoryException(
        'Could not load stock history: ${error.message}',
      );
    }
  }

  /// Loads all stock movements within a reporting period.
  ///
  /// The start is inclusive and the end is exclusive.
  /// Results are paginated so periods with more than 500
  /// movements are not silently truncated.
  Future<List<Map<String, dynamic>>> getMovementsBetween({
    required DateTime startInclusive,
    required DateTime endExclusive,
    int pageSize = 500,
  }) async {
    if (!endExclusive.isAfter(startInclusive)) {
      throw const StockMovementRepositoryException(
        'The report end date must be after its start date.',
      );
    }

    if (pageSize < 1) {
      throw const StockMovementRepositoryException(
        'The page size must be greater than zero.',
      );
    }

    final shopId = await _requireActiveShopId();

    try {
      final movementRows = <Map<String, dynamic>>[];

      var offset = 0;

      while (true) {
        final response = await _client
            .from('stock_movements')
            .select(
              'id, product_id, movement_type, quantity_delta, '
              'reason, reference_id, created_at',
            )
            .eq('shop_id', shopId)
            .gte(
              'created_at',
              startInclusive.toUtc().toIso8601String(),
            )
            .lt(
              'created_at',
              endExclusive.toUtc().toIso8601String(),
            )
            .order(
              'created_at',
              ascending: false,
            )
            .range(
              offset,
              offset + pageSize - 1,
            );

        final page = response
            .map<Map<String, dynamic>>(
              (row) => Map<String, dynamic>.from(row),
            )
            .toList(growable: false);

        movementRows.addAll(page);

        if (page.length < pageSize) {
          break;
        }

        offset += pageSize;
      }

      if (movementRows.isEmpty) {
        return const [];
      }

      final productIds = movementRows
          .map((row) => row['product_id'].toString())
          .toSet()
          .toList(growable: false);

      final products = await _client
          .from('products')
          .select('id, name, unit')
          .eq('shop_id', shopId)
          .inFilter('id', productIds);

      final productById = <String, Map<String, dynamic>>{
        for (final product in products)
          product['id'].toString():
              Map<String, dynamic>.from(product),
      };

      return movementRows.map((row) {
        final productId = row['product_id'].toString();
        final product = productById[productId];

        return <String, dynamic>{
          ...row,
          'product_name':
              product?['name']?.toString() ?? 'Unknown product',
          'product_unit':
              product?['unit']?.toString() ?? 'piece',
        };
      }).toList(growable: false);
    } on PostgrestException catch (error) {
      throw StockMovementRepositoryException(
        'Could not load stock movement report: ${error.message}',
      );
    }
  }  
}