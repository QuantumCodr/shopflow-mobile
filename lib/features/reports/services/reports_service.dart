import '../../inventory/models/inventory_item.dart';
import '../../inventory/services/inventory_service.dart';
import '../../sales_history/models/sale_history_models.dart';
import '../../sales_history/services/sales_history_service.dart';
import '../models/report_models.dart';

class ReportsServiceException implements Exception {
  const ReportsServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReportsService {
  ReportsService({
    SalesHistoryService? salesHistoryService,
    InventoryService? inventoryService,
  })  : _salesHistoryService =
            salesHistoryService ?? SalesHistoryService(),
        _inventoryService = inventoryService ?? InventoryService();

  final SalesHistoryService _salesHistoryService;
  final InventoryService _inventoryService;

  // =========================================================
  // PUBLIC API
  // =========================================================

  Future<ReportsSnapshot> loadReports({
    required ReportsPeriod period,
  }) async {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final startDate = _getStartDate(
      period: period,
      today: today,
    );

    // The end boundary is exclusive, so all timestamps occurring
    // during today are included without relying on 23:59:59.
    final endExclusive = DateTime(
      today.year,
      today.month,
      today.day + 1,
    );

    try {
      // Both requests run through the existing service layer.
      final results = await Future.wait<Object>([
        _salesHistoryService.getCompletedSalesBetween(
          startInclusive: startDate,
          endExclusive: endExclusive,
        ),
        _inventoryService.getInventory(),
      ]);

      final sales = results[0] as List<SaleHistoryRecord>;
      final inventory = results[1] as List<InventoryItem>;

      final dailySales = _buildDailySales(
        sales: sales,
        startDate: startDate,
        endExclusive: endExclusive,
      );

      final totalSalesMinor = sales.fold<int>(
        0,
        (total, sale) => total + sale.totalMinor,
      );

      final transactionCount = sales.length;

      final averageTransactionMinor = transactionCount == 0
          ? 0
          : (totalSalesMinor / transactionCount).round();

      final lowStockItems = inventory
          .where((item) => item.isLowStock)
          .toList(growable: false);

      final outOfStockItems = inventory
          .where((item) => item.isOutOfStock)
          .toList(growable: false);

      // Out-of-stock items appear first. Remaining low-stock items
      // are sorted by available quantity, lowest first.
      final stockAttentionItems = [
        ...outOfStockItems,
        ..._sortLowStockItems(lowStockItems),
      ];

      return ReportsSnapshot(
        period: period,
        startInclusive: startDate,
        endExclusive: endExclusive,
        totalSalesMinor: totalSalesMinor,
        transactionCount: transactionCount,
        averageTransactionMinor: averageTransactionMinor,
        dailySales: List.unmodifiable(dailySales),
        activeProductCount: inventory.length,
        lowStockCount: lowStockItems.length,
        outOfStockCount: outOfStockItems.length,
        stockAttentionItems: List.unmodifiable(
          stockAttentionItems,
        ),
      );
    } on SalesHistoryServiceException catch (error) {
      throw ReportsServiceException(error.message);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ReportsServiceException(
          'Could not load reports: $error',
        ),
        stackTrace,
      );
    }
  }

  // =========================================================
  // PERIOD CALCULATION
  // =========================================================

  DateTime _getStartDate({
    required ReportsPeriod period,
    required DateTime today,
  }) {
    switch (period) {
      case ReportsPeriod.last7Days:
        return DateTime(
          today.year,
          today.month,
          today.day - 6,
        );

      case ReportsPeriod.last30Days:
        return DateTime(
          today.year,
          today.month,
          today.day - 29,
        );

      case ReportsPeriod.thisMonth:
        return DateTime(
          today.year,
          today.month,
          1,
        );
    }
  }

  // =========================================================
  // DAILY SALES BREAKDOWN
  // =========================================================

  List<DailySalesPoint> _buildDailySales({
    required List<SaleHistoryRecord> sales,
    required DateTime startDate,
    required DateTime endExclusive,
  }) {
    final totalsByDate = <DateTime, _DailySalesAccumulator>{};

    // Create an entry for every day, including days with no sales.
    var currentDate = startDate;

    while (currentDate.isBefore(endExclusive)) {
      totalsByDate[currentDate] = _DailySalesAccumulator();

      currentDate = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day + 1,
      );
    }

    for (final sale in sales) {
      final localDate = sale.createdAt.toLocal();

      final date = DateTime(
        localDate.year,
        localDate.month,
        localDate.day,
      );

      final accumulator = totalsByDate[date];

      // Ignore a record outside the selected calendar range.
      if (accumulator == null) continue;

      accumulator.salesMinor += sale.totalMinor;
      accumulator.transactionCount++;
    }

    return totalsByDate.entries.map((entry) {
      return DailySalesPoint(
        date: entry.key,
        salesMinor: entry.value.salesMinor,
        transactionCount: entry.value.transactionCount,
      );
    }).toList(growable: false);
  }

  // =========================================================
  // INVENTORY HELPERS
  // =========================================================

  List<InventoryItem> _sortLowStockItems(
    List<InventoryItem> items,
  ) {
    final sorted = List<InventoryItem>.from(items);

    sorted.sort((a, b) {
      final quantityComparison =
          a.quantity.compareTo(b.quantity);

      if (quantityComparison != 0) {
        return quantityComparison;
      }

      return a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          );
    });

    return sorted;
  }
}

class _DailySalesAccumulator {
  int salesMinor = 0;
  int transactionCount = 0;
}