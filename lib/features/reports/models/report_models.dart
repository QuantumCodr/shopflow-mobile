import '../../inventory/models/inventory_item.dart';

enum ReportsPeriod {
  last7Days,
  last30Days,
  thisMonth,
}

extension ReportsPeriodLabel on ReportsPeriod {
  String get label {
    switch (this) {
      case ReportsPeriod.last7Days:
        return '7 days';
      case ReportsPeriod.last30Days:
        return '30 days';
      case ReportsPeriod.thisMonth:
        return 'This month';
    }
  }
}

class DailySalesPoint {
  const DailySalesPoint({
    required this.date,
    required this.salesMinor,
    required this.transactionCount,
  });

  final DateTime date;
  final int salesMinor;
  final int transactionCount;
}

class ProductPerformancePoint {
  const ProductPerformancePoint({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.revenueMinor,
    required this.costMinor,
    required this.grossProfitMinor,
    required this.transactionCount,
  });

  final String productId;
  final String productName;

  /// Quantity sold during the selected reporting period.
  final double quantitySold;

  /// Sales revenue in minor currency units.
  final int revenueMinor;

  /// Estimated cost of goods sold in minor currency units.
  final int costMinor;

  /// Revenue minus estimated cost of goods sold.
  final int grossProfitMinor;

  /// Number of distinct transactions containing this product.
  final int transactionCount;
}

class CategoryPerformancePoint {
  const CategoryPerformancePoint({
    required this.categoryId,
    required this.categoryName,
    required this.assignedProductCount,
    required this.quantitySold,
    required this.revenueMinor,
  });

  final String categoryId;
  final String categoryName;
  final int assignedProductCount;
  final double quantitySold;
  final int revenueMinor;
}

class PaymentMethodPoint {
  const PaymentMethodPoint({
    required this.paymentMethod,
    required this.transactionCount,
    required this.totalMinor,
  });

  final String paymentMethod;
  final int transactionCount;
  final int totalMinor;
}

class StockMovementReportEntry {
  const StockMovementReportEntry({
    required this.id,
    required this.productName,
    required this.productUnit,
    required this.movementType,
    required this.quantityDelta,
    required this.createdAt,
    this.reason,
  });

  final String id;
  final String productName;
  final String productUnit;
  final String movementType;

  /// Positive means stock increased; negative means stock decreased.
  final double quantityDelta;

  final DateTime createdAt;
  final String? reason;
}

class ReportsSnapshot {
  const ReportsSnapshot({
    required this.period,
    required this.startInclusive,
    required this.endExclusive,
    required this.totalSalesMinor,
    required this.transactionCount,
    required this.averageTransactionMinor,
    required this.dailySales,
    required this.activeProductCount,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.stockAttentionItems,
    this.productPerformance = const [],
    this.categoryPerformance = const [],
    this.paymentMethods = const [],
    this.stockMovements = const [],
    this.stockInQuantity = 0,
    this.stockOutQuantity = 0,
    this.stockSoldQuantity = 0,
  });

  final ReportsPeriod period;
  final DateTime startInclusive;
  final DateTime endExclusive;

  final int totalSalesMinor;
  final int transactionCount;
  final int averageTransactionMinor;

  final List<DailySalesPoint> dailySales;

  final int activeProductCount;
  final int lowStockCount;
  final int outOfStockCount;
  final List<InventoryItem> stockAttentionItems;

  final List<ProductPerformancePoint> productPerformance;
  final List<CategoryPerformancePoint> categoryPerformance;
  final List<PaymentMethodPoint> paymentMethods;
  final List<StockMovementReportEntry> stockMovements;

  /// Total positive stock movement during the selected period.
  final double stockInQuantity;

  /// Total quantity removed from inventory during the selected period.
  final double stockOutQuantity;

  /// Subset of stock-out quantity caused by completed POS sales.
  final double stockSoldQuantity;
}