import '../../products/models/product.dart';

/// A product with its current available stock.
class PosCatalogItem {
  const PosCatalogItem({
    required this.product,
    required this.availableQuantity,
  });

  final Product product;
  final int availableQuantity;
}

/// One product and its selected quantity in the cart.
class PosCartLine {
  const PosCartLine({
    required this.product,
    required this.quantity,
  });

  final Product product;
  final int quantity;

  int get lineTotal => product.sellingPrice * quantity;
}

/// Summary returned by a completed sale.
class PosReceipt {
  const PosReceipt({
    required this.saleId,
    required this.saleNumber,
    required this.subtotal,
    required this.total,
    required this.payment,
    required this.change,
  });

  final String saleId;
  final String saleNumber;
  final int subtotal;
  final int total;
  final int payment;
  final int change;

  factory PosReceipt.fromMap(Map<String, dynamic> map) {
    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();

      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return PosReceipt(
      saleId: map['sale_id']?.toString() ?? '',
      saleNumber: map['sale_number']?.toString() ?? '',
      subtotal: readInt(map['subtotal']),
      total: readInt(map['total']),
      payment: readInt(map['payment']),
      change: readInt(map['change']),
    );
  }
}