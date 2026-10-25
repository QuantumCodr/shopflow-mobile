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

  /// Returns the active shop belonging to the signed-in user.
  ///
  /// The database's ownership policies remain responsible for access control.
  Future<String> _requireActiveShopId() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw const PosRepositoryException(
        'You must be signed in to use the point of sale.',
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
        throw const PosRepositoryException(
          'No active shop was found for this account.',
        );
      }

      final shopId = response['id']?.toString();

      if (shopId == null || shopId.isEmpty) {
        throw const PosRepositoryException(
          'The active shop does not have a valid ID.',
        );
      }

      return shopId;
    } on PostgrestException catch (error) {
      throw PosRepositoryException(
        'Could not identify your active shop: ${error.message}',
      );
    }
  }

  /// Loads stock levels for the active shop.
  ///
  /// This method currently requires whole-number quantities because the
  /// existing POS models use int quantities. It deliberately rejects
  /// fractional stock rather than silently truncating it.
  Future<Map<String, int>> getStockLevels() async {
    final shopId = await _requireActiveShopId();

    try {
      final response = await _client
          .from('inventory')
          .select('product_id, quantity')
          .eq('shop_id', shopId);

      final result = <String, int>{};

      for (final row in response) {
        final productId = row['product_id']?.toString();

        if (productId == null || productId.isEmpty) {
          continue;
        }

        final dynamic rawQuantity = row['quantity'];

        final double? parsedQuantity;

        if (rawQuantity is num) {
          parsedQuantity = rawQuantity.toDouble();
        } else {
          parsedQuantity = double.tryParse(
            rawQuantity?.toString() ?? '',
          );
        }

        if (parsedQuantity == null || !parsedQuantity.isFinite) {
          throw const PosRepositoryException(
            'The server returned an invalid stock quantity.',
          );
        }

        if (parsedQuantity < 0) {
          throw const PosRepositoryException(
            'The server returned a negative stock quantity.',
          );
        }

        if (parsedQuantity % 1 != 0) {
          throw const PosRepositoryException(
            'Fractional stock was found. The current POS supports '
            'whole-number quantities only. Decimal quantity support '
            'must be added before selling fractional amounts.',
          );
        }

        result[productId] = parsedQuantity.toInt();
      }

      return result;
    } on PostgrestException catch (error) {
      throw PosRepositoryException(
        'Could not load stock levels: ${error.message}',
      );
    }
  }

  /// Records a sale through the PostgreSQL complete_sale function.
  ///
  /// The database function must validate ownership, prices, quantities,
  /// available stock, and payment before committing the transaction.
  Future<Map<String, dynamic>> completeSale({
    required List<Map<String, dynamic>> items,
    required int paymentAmount,
  }) async {
    if (items.isEmpty) {
      throw const PosRepositoryException(
        'Cannot submit a sale without any items.',
      );
    }

    if (paymentAmount < 0) {
      throw const PosRepositoryException(
        'The payment amount cannot be negative.',
      );
    }

    final shopId = await _requireActiveShopId();

    try {
      final dynamic response = await _client.rpc(
        'complete_sale',
        params: {
          'p_shop_id': shopId,
          'p_items': items,
          'p_amount_paid_minor': paymentAmount,
          'p_payment_method': 'cash',
          'p_discount_minor': 0,
        },
      );

      if (response is! Map) {
        throw const PosRepositoryException(
          'The server did not return a valid sale receipt.',
        );
      }

      final result = Map<String, dynamic>.from(response);

      return _normalizeReceipt(result);
    } on PostgrestException catch (error) {
      throw PosRepositoryException(
        'The sale could not be completed: ${error.message}',
      );
    }
  }

  /// Adds the keys expected by the existing PosReceipt.fromMap() method.
  ///
  /// The database's original response keys are preserved as well.
  Map<String, dynamic> _normalizeReceipt(
    Map<String, dynamic> response,
  ) {
    final dynamic saleNumber =
        response['sale_number'] ??
        response['saleNumber'] ??
        response['receipt_number'];

    final dynamic total =
        response['total_minor'] ??
        response['total'] ??
        response['total_amount_minor'];

    final dynamic payment =
        response['amount_paid_minor'] ??
        response['payment'] ??
        response['payment_minor'];

    final dynamic change =
        response['change_minor'] ??
        response['change'] ??
        response['change_amount_minor'];

    if (saleNumber == null ||
        total == null ||
        payment == null ||
        change == null) {
      throw const PosRepositoryException(
        'The sale may have been submitted, but the server response '
        'is missing receipt information. Check the complete_sale '
        'function response before attempting another checkout.',
      );
    }

    final normalizedTotal = _toInt(total);
    final normalizedPayment = _toInt(payment);
    final normalizedChange = _toInt(change);

    if (normalizedTotal == null ||
        normalizedPayment == null ||
        normalizedChange == null) {
      throw const PosRepositoryException(
        'The server returned invalid receipt amounts.',
      );
    }

    return {
      ...response,

      // Keys used by the current receipt model.
      'sale_number': saleNumber.toString(),
      'total': normalizedTotal,
      'payment': normalizedPayment,
      'change': normalizedChange,

      // Keep the database naming convention available too.
      'total_minor': normalizedTotal,
      'amount_paid_minor': normalizedPayment,
      'change_minor': normalizedChange,
    };
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;

    if (value is num) {
      if (!value.isFinite || value % 1 != 0) return null;
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }
}