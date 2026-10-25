class SaleHistoryRecord {
  const SaleHistoryRecord({
    required this.id,
    required this.saleNumber,
    required this.status,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.totalMinor,
    required this.amountPaidMinor,
    required this.changeMinor,
    required this.paymentMethod,
    required this.createdAt,
  });

  final String id;
  final String saleNumber;
  final String status;

  final int subtotalMinor;
  final int discountMinor;
  final int totalMinor;
  final int amountPaidMinor;
  final int changeMinor;

  final String paymentMethod;
  final DateTime createdAt;

  bool get isCompleted => status == 'completed';

  bool get isVoided => status == 'voided';

  factory SaleHistoryRecord.fromMap(
    Map<String, dynamic> map,
  ) {
    return SaleHistoryRecord(
      id: map['id'].toString(),
      saleNumber: map['sale_number'].toString(),
      status: map['status'].toString().toLowerCase(),
      subtotalMinor: _readInteger(map['subtotal_minor']),
      discountMinor: _readInteger(map['discount_minor']),
      totalMinor: _readInteger(map['total_minor']),
      amountPaidMinor: _readInteger(
        map['amount_paid_minor'],
      ),
      changeMinor: _readInteger(map['change_minor']),
      paymentMethod: map['payment_method'].toString(),
      createdAt: DateTime.parse(
        map['created_at'].toString(),
      ),
    );
  }
}

class SaleHistoryItem {
  const SaleHistoryItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPriceMinor,
    required this.unitCostMinor,
    required this.lineTotalMinor,
  });

  final String id;
  final String saleId;
  final String productId;
  final String productName;

  final double quantity;

  final int unitPriceMinor;
  final int unitCostMinor;
  final int lineTotalMinor;

  factory SaleHistoryItem.fromMap(
    Map<String, dynamic> map,
  ) {
    return SaleHistoryItem(
      id: map['id'].toString(),
      saleId: map['sale_id'].toString(),
      productId: map['product_id'].toString(),
      productName: map['product_name'].toString(),
      quantity: _readDouble(map['quantity']),
      unitPriceMinor: _readInteger(
        map['unit_price_minor'],
      ),
      unitCostMinor: _readInteger(
        map['unit_cost_minor'],
      ),
      lineTotalMinor: _readInteger(
        map['line_total_minor'],
      ),
    );
  }
}

int _readInteger(dynamic value) {
  if (value is int) return value;

  if (value is num && value.isFinite) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _readDouble(dynamic value) {
  if (value is num && value.isFinite) {
    return value.toDouble();
  }

  return double.tryParse(
        value?.toString() ?? '',
      ) ??
      0;
}