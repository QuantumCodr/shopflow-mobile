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

  /// Total completed sales for this calendar day, in minor units.
  final int salesMinor;

  /// Number of completed transactions for this calendar day.
  final int transactionCount;
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
  });

  final ReportsPeriod period;

  /// First included calendar day.
  final DateTime startInclusive;

  /// Exclusive end boundary used for database queries.
  final DateTime endExclusive;

  /// Total of completed sales in the selected period.
  final int totalSalesMinor;

  /// Number of completed sales in the selected period.
  final int transactionCount;

  /// Average completed sale value, in minor units.
  final int averageTransactionMinor;

  /// Daily breakdown for the selected period.
  final List<DailySalesPoint> dailySales;

  /// Number of active products returned by InventoryService.
  final int activeProductCount;

  /// Active products with positive stock at or below the reorder level.
  final int lowStockCount;

  /// Active products with zero or negative stock.
  final int outOfStockCount;

  /// Products requiring attention, with out-of-stock items first.
  final List<InventoryItem> stockAttentionItems;
}