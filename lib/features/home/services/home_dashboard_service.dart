import '../../../shared/time/shopflow_time.dart';
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

  /// Total completed sales in minor currency units.
  final int todaySalesMinor;

  /// Number of completed transactions today.
  final int todayTransactionCount;

  /// Active products at or below their reorder threshold,
  /// including out-of-stock products.
  final List<InventoryItem> lowStockItems;

  /// Most recent completed sales.
  final List<SaleHistoryRecord> recentSales;
}

class HomeDashboardService {
  HomeDashboardService({
    SalesHistoryService? salesHistoryService,
    InventoryService? inventoryService,
  })  : _salesHistoryService =
            salesHistoryService ?? SalesHistoryService(),
        _inventoryService =
            inventoryService ?? InventoryService();

  final SalesHistoryService _salesHistoryService;
  final InventoryService _inventoryService;

  Future<HomeDashboardData> loadDashboard() async {
    // Use Sierra Leone's business-day boundaries.
    // Do not derive these boundaries from Windows' local timezone.
    final startOfToday = ShopFlowTime.startOfTodayUtc();
    final startOfTomorrow = ShopFlowTime.startOfTomorrowUtc();

    try {
      // Load dashboard data concurrently through existing services.
      final results = await Future.wait<Object>([
        _salesHistoryService.getCompletedSalesBetween(
          startInclusive: startOfToday,
          endExclusive: startOfTomorrow,
        ),
        _salesHistoryService.getRecentCompletedSales(
          limit: 5,
        ),
        _inventoryService.getInventory(),
      ]);

      final todaySales =
          results[0] as List<SaleHistoryRecord>;

      final recentSales =
          results[1] as List<SaleHistoryRecord>;

      final inventory =
          results[2] as List<InventoryItem>;

      final todaySalesMinor = todaySales.fold<int>(
        0,
        (total, sale) => total + sale.totalMinor,
      );

      final lowStockItems = inventory
          .where(
            (item) =>
                item.isLowStock || item.isOutOfStock,
          )
          .toList();

      // Show out-of-stock products first, followed by the
      // smallest available quantities.
      lowStockItems.sort((a, b) {
        if (a.isOutOfStock && !b.isOutOfStock) {
          return -1;
        }

        if (!a.isOutOfStock && b.isOutOfStock) {
          return 1;
        }

        final quantityComparison =
            a.quantity.compareTo(b.quantity);

        if (quantityComparison != 0) {
          return quantityComparison;
        }

        return a.name.toLowerCase().compareTo(
              b.name.toLowerCase(),
            );
      });

      return HomeDashboardData(
        todaySalesMinor: todaySalesMinor,
        todayTransactionCount: todaySales.length,
        lowStockItems: List.unmodifiable(lowStockItems),
        recentSales: List.unmodifiable(recentSales),
      );
    } on SalesHistoryServiceException catch (error) {
      throw HomeDashboardServiceException(
        error.message,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        HomeDashboardServiceException(
          'Could not load dashboard data: $error',
        ),
        stackTrace,
      );
    }
  }
}