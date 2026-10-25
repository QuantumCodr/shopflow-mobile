import '../../inventory/models/inventory_item.dart';
import '../../inventory/services/inventory_service.dart';
import '../../sales_history/models/sale_history_models.dart';
import '../../sales_history/services/sales_history_service.dart';

class HomeDashboardServiceException implements Exception {
  const HomeDashboardServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HomeDashboardData {
  const HomeDashboardData({
    required this.todaySalesMinor,
    required this.todayTransactionCount,
    required this.lowStockItems,
    required this.recentSales,
  });

  /// Total of completed sales, represented in minor currency units.
  final int todaySalesMinor;

  /// Number of completed sales today.
  final int todayTransactionCount;

  /// Active products at or below their reorder threshold.
  final List<InventoryItem> lowStockItems;

  /// Most recent completed sales.
  final List<SaleHistoryRecord> recentSales;
}

class HomeDashboardService {
  HomeDashboardService({
    SalesHistoryService? salesHistoryService,
    InventoryService? inventoryService,
  }) : _salesHistoryService = salesHistoryService ?? SalesHistoryService(),
       _inventoryService = inventoryService ?? InventoryService();

  final SalesHistoryService _salesHistoryService;
  final InventoryService _inventoryService;

  Future<HomeDashboardData> loadDashboard() async {
    // Use the device's local calendar day.
    //
    // The repository converts these boundaries to UTC before querying
    // the timestamp column. Using an exclusive end boundary avoids
    // accidentally excluding sales with fractional-second timestamps.
    final now = DateTime.now();

    final startOfToday = DateTime(now.year, now.month, now.day);

    final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);

    try {
      // Load all dashboard sections concurrently through the services.
      final results = await Future.wait<Object>([
        _salesHistoryService.getCompletedSalesBetween(
          startInclusive: startOfToday,
          endExclusive: startOfTomorrow,
        ),
        _salesHistoryService.getRecentCompletedSales(limit: 5),
        _inventoryService.getInventory(),
      ]);

      final todaySales = results[0] as List<SaleHistoryRecord>;
      final recentSales = results[1] as List<SaleHistoryRecord>;
      final inventory = results[2] as List<InventoryItem>;

      final todaySalesMinor = todaySales.fold<int>(
        0,
        (total, sale) => total + sale.totalMinor,
      );

      // InventoryService already returns active products.
      // Include out-of-stock products even when their reorder level is 0.
      final lowStockItems = inventory
          .where((item) => item.isLowStock || item.isOutOfStock)
          .toList();

      // Put out-of-stock products first, then products with the
      // lowest available quantity.
      lowStockItems.sort((a, b) {
        if (a.isOutOfStock && !b.isOutOfStock) return -1;
        if (!a.isOutOfStock && b.isOutOfStock) return 1;

        final quantityComparison = a.quantity.compareTo(b.quantity);

        if (quantityComparison != 0) {
          return quantityComparison;
        }

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return HomeDashboardData(
        todaySalesMinor: todaySalesMinor,
        todayTransactionCount: todaySales.length,
        lowStockItems: List.unmodifiable(lowStockItems),
        recentSales: List.unmodifiable(recentSales),
      );
    } on SalesHistoryServiceException catch (error) {
      throw HomeDashboardServiceException(error.message);
    } catch (error, stackTrace) {
      // InventoryService currently passes repository exceptions through,
      // so this layer translates unexpected failures into a UI-friendly
      // dashboard exception.
      Error.throwWithStackTrace(
        HomeDashboardServiceException('Could not load dashboard data: $error'),
        stackTrace,
      );
    }
  }
}
