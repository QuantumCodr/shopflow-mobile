class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productUnit,
    required this.movementType,
    required this.quantityDelta,
    required this.createdAt,
    this.reason,
    this.referenceId,
  });

  final String id;
  final String productId;
  final String productName;
  final String productUnit;

  final String movementType;

  /// Positive quantity means stock increased.
  /// Negative quantity means stock decreased.
  final double quantityDelta;

  final String? reason;
  final String? referenceId;
  final DateTime createdAt;

  bool get isStockIn => quantityDelta > 0;

  bool get isStockOut => quantityDelta < 0;

  factory StockMovement.fromMap(
    Map<String, dynamic> map,
  ) {
    return StockMovement(
      id: map['id'].toString(),
      productId: map['product_id'].toString(),
      productName:
          map['product_name']?.toString() ?? 'Unknown product',
      productUnit:
          map['product_unit']?.toString() ?? 'piece',
      movementType: map['movement_type'].toString(),
      quantityDelta: _readDouble(map['quantity_delta']),
      reason: map['reason']?.toString(),
      referenceId: map['reference_id']?.toString(),
      createdAt: DateTime.parse(
        map['created_at'].toString(),
      ),
    );
  }
}

double _readDouble(dynamic value) {
  if (value is num && value.isFinite) {
    return value.toDouble();
  }

  final parsed = double.tryParse(
    value?.toString() ?? '',
  );

  if (parsed == null || !parsed.isFinite) {
    throw const FormatException(
      'Invalid stock movement quantity.',
    );
  }

  return parsed;
}