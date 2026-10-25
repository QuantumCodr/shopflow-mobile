import '../../../shared/time/shopflow_time.dart';
import '../../categories/services/category_service.dart';
import '../../inventory/models/inventory_item.dart';
import '../../inventory/services/inventory_service.dart';
import '../../sales_history/models/sale_history_models.dart';
import '../../sales_history/services/sales_history_service.dart';
import '../../stock_movements/models/stock_movement_model.dart';
import '../../stock_movements/services/stock_movement_service.dart';
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
    CategoryService? categoryService,
    StockMovementService? stockMovementService,
  })  : _salesHistoryService =
            salesHistoryService ?? SalesHistoryService(),
        _inventoryService = inventoryService ?? InventoryService(),
        _categoryService = categoryService ?? CategoryService(),
        _stockMovementService =
            stockMovementService ?? StockMovementService();

  final SalesHistoryService _salesHistoryService;
  final InventoryService _inventoryService;
  final CategoryService _categoryService;
  final StockMovementService _stockMovementService;

  // =========================================================
  // PUBLIC API
  // =========================================================

  Future<ReportsSnapshot> loadReports({
    required ReportsPeriod period,
  }) async {
    // Use Sierra Leone business time rather than the computer's
    // configured local timezone.
    final today = ShopFlowTime.startOfTodayUtc();

    final startDate = _getStartDate(
      period: period,
      today: today,
    );

    // Exclusive boundary: midnight at the beginning of tomorrow.
    final endExclusive = DateTime.utc(
      today.year,
      today.month,
      today.day + 1,
    );

    try {
      // Load all primary datasets through the existing service layer.
      final results = await Future.wait<Object>([
        _salesHistoryService.getCompletedSalesBetween(
          startInclusive: startDate,
          endExclusive: endExclusive,
        ),
        _inventoryService.getInventory(),
        _categoryService.getCategories(),
        _stockMovementService.getMovementsBetween(
          startInclusive: startDate,
          endExclusive: endExclusive,
        ),
      ]);

      final sales = results[0] as List<SaleHistoryRecord>;
      final inventory = results[1] as List<InventoryItem>;
      final categories = results[2] as List;
      final movements = results[3] as List<StockMovement>;

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

      final productPerformance = await _buildProductPerformance(
        sales: sales,
      );

      final categoryPerformance = await _buildCategoryPerformance(
        categories: categories,
        products: productPerformance,
      );

      final paymentMethods = _buildPaymentMethods(sales);

      final stockMovements = movements
          .map(
            (movement) => StockMovementReportEntry(
              id: movement.id,
              productName: movement.productName,
              productUnit: movement.productUnit,
              movementType: movement.movementType,
              quantityDelta: movement.quantityDelta,
              createdAt: movement.createdAt,
              reason: movement.reason,
            ),
          )
          .toList(growable: false);

      final stockInQuantity = movements
          .where((movement) => movement.quantityDelta > 0)
          .fold<double>(
            0,
            (total, movement) => total + movement.quantityDelta,
          );

      final stockOutQuantity = movements
          .where((movement) => movement.quantityDelta < 0)
          .fold<double>(
            0,
            (total, movement) =>
                total + movement.quantityDelta.abs(),
          );

      final stockSoldQuantity = movements
          .where((movement) => movement.movementType == 'sale')
          .fold<double>(
            0,
            (total, movement) =>
                total + movement.quantityDelta.abs(),
          );

      final lowStockItems = inventory
          .where((item) => item.isLowStock)
          .toList(growable: false);

      final outOfStockItems = inventory
          .where((item) => item.isOutOfStock)
          .toList(growable: false);

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
        productPerformance: List.unmodifiable(productPerformance),
        categoryPerformance: List.unmodifiable(categoryPerformance),
        paymentMethods: List.unmodifiable(paymentMethods),
        stockMovements: List.unmodifiable(stockMovements),
        stockInQuantity: stockInQuantity,
        stockOutQuantity: stockOutQuantity,
        stockSoldQuantity: stockSoldQuantity,
      );
    } on SalesHistoryServiceException catch (error) {
      throw ReportsServiceException(error.message);
    } on CategoryServiceException catch (error) {
      throw ReportsServiceException(error.message);
    } on StockMovementServiceException catch (error) {
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
  // PRODUCT PERFORMANCE
  // =========================================================

  Future<List<ProductPerformancePoint>> _buildProductPerformance({
    required List<SaleHistoryRecord> sales,
  }) async {
    final accumulators = <String, _ProductAccumulator>{};

    // Process sales in batches to limit concurrent database requests.
    const batchSize = 10;

    for (var offset = 0; offset < sales.length; offset += batchSize) {
      final batch = sales.skip(offset).take(batchSize).toList();

      final itemsBySale = await Future.wait<List<SaleHistoryItem>>(
        batch.map(
          (sale) => _salesHistoryService.getSaleItems(
            saleId: sale.id,
          ),
        ),
      );

      for (var i = 0; i < batch.length; i++) {
        final items = itemsBySale[i];
        final productIdsInThisSale = <String>{};

        for (final item in items) {
          final accumulator = accumulators.putIfAbsent(
            item.productId,
            () => _ProductAccumulator(
              productId: item.productId,
              productName: item.productName,
            ),
          );

          accumulator.quantitySold += item.quantity;
          accumulator.revenueMinor += item.lineTotalMinor;

          accumulator.costMinor +=
              (item.quantity * item.unitCostMinor).round();

          productIdsInThisSale.add(item.productId);
        }

        // Count a product once per transaction, even if duplicate
        // item records somehow exist for that product in a sale.
        for (final productId in productIdsInThisSale) {
          accumulators[productId]!.transactionCount++;
        }
      }
    }

    final result = accumulators.values.map((item) {
      return ProductPerformancePoint(
        productId: item.productId,
        productName: item.productName,
        quantitySold: item.quantitySold,
        revenueMinor: item.revenueMinor,
        costMinor: item.costMinor,
        grossProfitMinor: item.revenueMinor - item.costMinor,
        transactionCount: item.transactionCount,
      );
    }).toList();

    // Rank by quantity sold, then revenue.
    result.sort((a, b) {
      final quantityComparison =
          b.quantitySold.compareTo(a.quantitySold);

      if (quantityComparison != 0) {
        return quantityComparison;
      }

      return b.revenueMinor.compareTo(a.revenueMinor);
    });

    return result;
  }

  // =========================================================
  // CATEGORY PERFORMANCE
  // =========================================================

  Future<List<CategoryPerformancePoint>> _buildCategoryPerformance({
    required List categories,
    required List<ProductPerformancePoint> products,
  }) async {
    if (categories.isEmpty) {
      return const [];
    }

    final assignedProductsByCategory = await Future.wait<List>(
      categories.map(
        (category) => _categoryService.getProductsForCategory(
          categoryId: category.id.toString(),
        ),
      ),
    );

    final productById = <String, ProductPerformancePoint>{
      for (final product in products)
        product.productId: product,
    };

    final result = <CategoryPerformancePoint>[];

    for (var i = 0; i < categories.length; i++) {
      final category = categories[i];
      final options = assignedProductsByCategory[i];

      final assignedIds = options
          .where((option) => option.isAssigned)
          .map((option) => option.id.toString())
          .toSet();

      var quantitySold = 0.0;
      var revenueMinor = 0;

      for (final productId in assignedIds) {
        final product = productById[productId];

        if (product == null) continue;

        quantitySold += product.quantitySold;
        revenueMinor += product.revenueMinor;
      }

      result.add(
        CategoryPerformancePoint(
          categoryId: category.id.toString(),
          categoryName: category.name.toString(),
          assignedProductCount: assignedIds.length,
          quantitySold: quantitySold,
          revenueMinor: revenueMinor,
        ),
      );
    }

    result.sort(
      (a, b) => b.revenueMinor.compareTo(a.revenueMinor),
    );

    return result;
  }

  // =========================================================
  // PAYMENT METHODS
  // =========================================================

  List<PaymentMethodPoint> _buildPaymentMethods(
    List<SaleHistoryRecord> sales,
  ) {
    final accumulators = <String, _PaymentMethodAccumulator>{};

    for (final sale in sales) {
      final rawMethod = sale.paymentMethod.trim().toLowerCase();
      final method = rawMethod.isEmpty ? 'unknown' : rawMethod;

      final accumulator = accumulators.putIfAbsent(
        method,
        () => _PaymentMethodAccumulator(method),
      );

      accumulator.transactionCount++;
      accumulator.totalMinor += sale.totalMinor;
    }

    final result = accumulators.values.map((item) {
      return PaymentMethodPoint(
        paymentMethod: _formatPaymentMethod(item.paymentMethod),
        transactionCount: item.transactionCount,
        totalMinor: item.totalMinor,
      );
    }).toList();

    result.sort(
      (a, b) => b.totalMinor.compareTo(a.totalMinor),
    );

    return result;
  }

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'mobile_money':
        return 'Mobile money';
      case 'card':
        return 'Card';
      case 'other':
        return 'Other';
      case 'unknown':
        return 'Unknown';
      default:
        return method
            .split('_')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
            )
            .join(' ');
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
        return DateTime.utc(
          today.year,
          today.month,
          today.day - 6,
        );

      case ReportsPeriod.last30Days:
        return DateTime.utc(
          today.year,
          today.month,
          today.day - 29,
        );

      case ReportsPeriod.thisMonth:
        return DateTime.utc(
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
    // All calendar keys use UTC so their year, month and day
    // represent Sierra Leone business dates independently of Windows.
    final totalsByDate = <DateTime, _DailySalesAccumulator>{};

    var currentDate = startDate;

    while (currentDate.isBefore(endExclusive)) {
      totalsByDate[currentDate] = _DailySalesAccumulator();

      currentDate = DateTime.utc(
        currentDate.year,
        currentDate.month,
        currentDate.day + 1,
      );
    }

    for (final sale in sales) {
      // Convert each event to the business timezone.
      // For Sierra Leone, UTC and business time have the same clock.
      final businessTime = ShopFlowTime.toBusinessTime(
        sale.createdAt,
      );

      final date = DateTime.utc(
        businessTime.year,
        businessTime.month,
        businessTime.day,
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

class _ProductAccumulator {
  _ProductAccumulator({
    required this.productId,
    required this.productName,
  });

  final String productId;
  final String productName;

  double quantitySold = 0;
  int revenueMinor = 0;
  int costMinor = 0;
  int transactionCount = 0;
}

class _PaymentMethodAccumulator {
  _PaymentMethodAccumulator(this.paymentMethod);

  final String paymentMethod;

  int transactionCount = 0;
  int totalMinor = 0;
}