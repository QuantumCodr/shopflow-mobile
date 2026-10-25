import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shopflow_mobile/features/sales_history/data/sales_history_repository.dart';
import 'package:shopflow_mobile/shared/time/shopflow_time.dart';

import '../../../shared/formatters/sle_money.dart';
import '../../../shared/state/shopflow_events.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/shopflow_page_layout.dart';
import '../models/sale_history_models.dart';
import '../services/sales_history_service.dart';

enum _SalesFilter {
  all,
  completed,
  voided,
}

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({
    super.key,
    this.salesHistoryService, required String title, required String description, required IconData icon,
  });

  final SalesHistoryService? salesHistoryService;

  @override
  State<SalesHistoryScreen> createState() =>
      _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  late final SalesHistoryService _service;

  final TextEditingController _searchController =
      TextEditingController();

  List<SaleHistoryRecord> _sales = [];

  bool _isLoading = true;

  String? _errorMessage;
  String _searchQuery = '';

  _SalesFilter _filter = _SalesFilter.all;

  int _loadRevision = 0;

  @override
  void initState() {
    super.initState();

    _service =
        widget.salesHistoryService ?? SalesHistoryService();

    ShopFlowEvents.dataRevision.addListener(
      _handleDataChanged,
    );

    _loadSales();
  }

  @override
  void dispose() {
    ShopFlowEvents.dataRevision.removeListener(
      _handleDataChanged,
    );

    _searchController.dispose();

    super.dispose();
  }

  // =========================================================
  // DATA
  // =========================================================

  void _handleDataChanged() {
    if (!mounted) return;

    unawaited(_loadSales(silent: true));
  }

  Future<void> _loadSales({
    bool silent = false,
  }) async {
    if (!mounted) return;

    final revision = ++_loadRevision;

    setState(() {
      if (!silent || _sales.isEmpty) {
        _isLoading = true;
      }

      _errorMessage = null;
    });

    try {
      final sales = await _service.getRecentSales();

      if (!mounted || revision != _loadRevision) {
        return;
      }

      setState(() {
        _sales = sales;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Sales history loading failed: '
        '$error\n$stackTrace',
      );

      if (!mounted || revision != _loadRevision) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _friendlyError(error);
      });
    }
  }

  // =========================================================
  // SEARCH AND FILTERS
  // =========================================================

  List<SaleHistoryRecord> get _filteredSales {
    final query = _searchQuery.trim().toLowerCase();

    return _sales.where((sale) {
      final matchesFilter = switch (_filter) {
        _SalesFilter.all => true,
        _SalesFilter.completed => sale.isCompleted,
        _SalesFilter.voided => sale.isVoided,
      };

      if (!matchesFilter) return false;

      if (query.isEmpty) return true;

      final searchableText = [
        sale.saleNumber,
        sale.status,
        sale.paymentMethod,
        _paymentMethodLabel(sale.paymentMethod),
        _formatDateTime(sale.createdAt),
      ].join(' ').toLowerCase();

      return searchableText.contains(query);
    }).toList(growable: false);
  }

  int get _completedCount {
    return _sales.where((sale) => sale.isCompleted).length;
  }

  int get _voidedCount {
    return _sales.where((sale) => sale.isVoided).length;
  }


  // =========================================================
  // OPEN SALE DETAILS
  // =========================================================

  Future<void> _openSaleDetails(
    SaleHistoryRecord sale,
  ) async {
    // Fetch the line items only when their sale is opened.
    var itemsFuture = _service.getSaleItems(
      saleId: sale.id,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.78,
              minChildSize: 0.45,
              maxChildSize: 0.96,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildSheetHeader(
                        context,
                        sheetContext,
                        sale,
                      ),

                      const Divider(
                        height: 1,
                        color: AppColors.divider,
                      ),

                      Expanded(
                        child: FutureBuilder<List<SaleHistoryItem>>(
                          future: itemsFuture,
                          builder: (context, snapshot) {
                            return ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                18,
                                20,
                                24,
                              ),
                              children: [
                                _buildSaleSummary(sale),

                                const SizedBox(height: 24),

                                Text(
                                  'Items purchased',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color:
                                            AppColors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),

                                const SizedBox(height: 10),

                                if (snapshot.connectionState ==
                                    ConnectionState.waiting)
                                  const Padding(
                                    padding: EdgeInsets.all(30),
                                    child: Center(
                                      child:
                                          CircularProgressIndicator(),
                                    ),
                                  )
                                else if (snapshot.hasError)
                                  _buildDetailsError(
                                    snapshot.error,
                                    () {
                                      setSheetState(() {
                                        itemsFuture =
                                            _service.getSaleItems(
                                          saleId: sale.id,
                                        );
                                      });
                                    },
                                  )
                                else if (!snapshot.hasData ||
                                    snapshot.data!.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 24,
                                    ),
                                    child: Text(
                                      'No sale items were found.',
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                else ...[
                                  ...snapshot.data!.map(
                                    _buildSaleItemRow,
                                  ),
                                ],

                                const SizedBox(height: 24),

                                const Divider(
                                  color: AppColors.divider,
                                ),

                                const SizedBox(height: 12),

                                _DetailAmountRow(
                                  label: 'Subtotal',
                                  value: sale.subtotalMinor,
                                ),

                                if (sale.discountMinor > 0)
                                  _DetailAmountRow(
                                    label: 'Discount',
                                    value: sale.discountMinor,
                                    negative: true,
                                  ),

                                _DetailAmountRow(
                                  label: 'Total',
                                  value: sale.totalMinor,
                                  emphasized: true,
                                ),

                                const SizedBox(height: 12),

                                const Divider(
                                  color: AppColors.divider,
                                ),

                                const SizedBox(height: 12),

                                _DetailAmountRow(
                                  label: 'Amount received',
                                  value: sale.amountPaidMinor,
                                ),

                                _DetailAmountRow(
                                  label: 'Change',
                                  value: sale.changeMinor,
                                  emphasized: true,
                                ),

                                const SizedBox(height: 20),

                                SizedBox(
                                  height: 46,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.of(
                                        sheetContext,
                                      ).pop();
                                    },
                                    child: const Text('Close details'),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSheetHeader(
    BuildContext context,
    BuildContext sheetContext,
    SaleHistoryRecord sale,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        10,
        12,
        16,
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.brand,
                  size: 24,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sale #${sale.saleNumber}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(sale.createdAt),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),

              _StatusLabel(sale: sale),

              IconButton(
                tooltip: 'Close details',
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                },
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaleSummary(
    SaleHistoryRecord sale,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        children: [
          _DetailTextRow(
            label: 'Payment method',
            value: _paymentMethodLabel(sale.paymentMethod),
          ),

          const SizedBox(height: 12),

          _DetailTextRow(
            label: 'Transaction status',
            value: _statusLabel(sale.status),
          ),

          const SizedBox(height: 12),

          _DetailTextRow(
            label: 'Receipt number',
            value: '#${sale.saleNumber}',
          ),
        ],
      ),
    );
  }

  Widget _buildSaleItemRow(
    SaleHistoryItem item,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),

                const SizedBox(height: 5),

                Text(
                  '${_formatQuantity(item.quantity)} × '
                  'SLE ${formatSleMinor(item.unitPriceMinor)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Text(
            'SLE ${formatSleMinor(item.lineTotalMinor)}',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsError(
    Object? error,
    VoidCallback onRetry,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Could not load the sale items.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _friendlyError(error ?? 'Unknown error'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // DATE, PAYMENT AND STATUS FORMATTING
  // =========================================================

  String _formatDateTime(DateTime value) {
    final date = ShopFlowTime.toBusinessTime(value);
    final now = ShopFlowTime.nowUtc();

    final today = DateTime(now.year, now.month, now.day);
    final saleDay = DateTime(date.year, date.month, date.day);

    final difference = today.difference(saleDay).inDays;

    final dayLabel = difference == 0
        ? 'Today'
        : difference == 1
            ? 'Yesterday'
            : '${date.day} ${_monthName(date.month)} ${date.year}';

    return '$dayLabel · '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return months[month - 1];
  }

  String _paymentMethodLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'mobile_money':
        return 'Mobile Money';
      case 'card':
        return 'Card';
      case 'other':
        return 'Other';
      default:
        return method;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'voided':
        return 'Voided';
      default:
        return status;
    }
  }

  String _formatQuantity(double quantity) {
    if (quantity == quantity.truncateToDouble()) {
      return quantity.toInt().toString();
    }

    return quantity
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _friendlyError(Object error) {
    if (error is SalesHistoryServiceException ||
        error is SalesHistoryRepositoryException) {
      return error.toString();
    }

    return 'We could not load this information. '
        'Please check your connection and try again.';
  }

  // =========================================================
  // MAIN SCREEN
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ShopFlowPageLayout(
        maxWidth: 820,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),

            const SizedBox(height: 16),

            _buildSummary(),

            const SizedBox(height: 16),

            _buildSearch(),

            const SizedBox(height: 12),

            _buildFilters(),

            if (_errorMessage != null && _sales.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildInlineError(),
            ],

            if (_isLoading && _sales.isNotEmpty)
              const LinearProgressIndicator(
                minHeight: 2,
              ),

            const SizedBox(height: 6),

            Expanded(
              child: _buildSalesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sales History',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Review previous transactions and receipts.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        IconButton(
          tooltip: 'Refresh sales history',
          onPressed: _isLoading
              ? null
              : () => _loadSales(),
          icon: const Icon(Icons.refresh_rounded),
          color: AppColors.brand,
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryMetric(
              label: 'Loaded sales',
              value: '${_sales.length}',
              icon: Icons.receipt_long_outlined,
            ),
          ),

          Container(
            width: 1,
            height: 42,
            color: AppColors.divider,
          ),

          Expanded(
            child: _SummaryMetric(
              label: 'Completed',
              value: '$_completedCount',
              icon: Icons.check_circle_outline_rounded,
              valueColor: AppColors.success,
            ),
          ),

          Container(
            width: 1,
            height: 42,
            color: AppColors.divider,
          ),

          Expanded(
            child: _SummaryMetric(
              label: 'Voided',
              value: '$_voidedCount',
              icon: Icons.block_outlined,
              valueColor: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search receipt number or payment method',
          hintStyle: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
                color: AppColors.textSecondary,
              ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 21,
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _searchController.clear();

                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 19,
                  ),
                ),
          filled: true,
          fillColor: AppColors.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(
              color: AppColors.border,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(
              color: AppColors.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(
              color: AppColors.brand,
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            label: 'All',
            value: _SalesFilter.all,
          ),

          const SizedBox(width: 8),

          _buildFilterChip(
            label: 'Completed',
            value: _SalesFilter.completed,
          ),

          const SizedBox(width: 8),

          _buildFilterChip(
            label: 'Voided',
            value: _SalesFilter.voided,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required _SalesFilter value,
  }) {
    final selected = _filter == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _filter = value;
        });
      },
      selectedColor: AppColors.brand.withValues(alpha: 0.12),
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: selected
            ? AppColors.brand
            : AppColors.border,
      ),
      labelStyle: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(
            color: selected
                ? AppColors.brand
                : AppColors.textSecondary,
            fontWeight: selected
                ? FontWeight.w700
                : FontWeight.w500,
          ),
      showCheckmark: false,
    );
  }

  Widget _buildInlineError() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 17,
            color: AppColors.error,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              'Refresh failed. Showing the last loaded sales.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
          ),

          TextButton(
            onPressed: _isLoading
                ? null
                : () => _loadSales(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesList() {
    if (_isLoading && _sales.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _sales.isEmpty) {
      return _EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load sales',
        message: _errorMessage!,
        actionLabel: 'Try again',
        onAction: () => _loadSales(),
      );
    }

    final sales = _filteredSales;

    if (sales.isEmpty) {
      final hasAnySales = _sales.isNotEmpty;

      return RefreshIndicator(
        onRefresh: _loadSales,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 60),

            Icon(
              hasAnySales
                  ? Icons.search_off_rounded
                  : Icons.receipt_long_outlined,
              size: 42,
              color: AppColors.textSecondary,
            ),

            const SizedBox(height: 14),

            Text(
              hasAnySales
                  ? 'No matching sales'
                  : 'No sales recorded yet',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),

            const SizedBox(height: 7),

            Text(
              hasAnySales
                  ? 'Try a different search or filter.'
                  : 'Completed sales will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSales,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          bottom: 16,
        ),
        itemCount: sales.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          color: AppColors.divider,
        ),
        itemBuilder: (context, index) {
          return _buildSaleRow(sales[index]);
        },
      ),
    );
  }

  Widget _buildSaleRow(
    SaleHistoryRecord sale,
  ) {
    final statusColor = sale.isCompleted
        ? AppColors.success
        : sale.isVoided
            ? AppColors.error
            : AppColors.warning;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openSaleDetails(sale),
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 13,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.brand,
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sale #${sale.saleNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      '${_formatDateTime(sale.createdAt)}'
                      ' · ${_paymentMethodLabel(sale.paymentMethod)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),

                        const SizedBox(width: 6),

                        Text(
                          _statusLabel(sale.status),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'SLE ${formatSleMinor(sale.totalMinor)}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),

                  const SizedBox(height: 5),

                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// SUMMARY METRIC
// ===========================================================

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: valueColor ?? AppColors.brand,
          ),

          const SizedBox(height: 8),

          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),

          const SizedBox(height: 3),

          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// STATUS LABEL
// ===========================================================

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({
    required this.sale,
  });

  final SaleHistoryRecord sale;

  @override
  Widget build(BuildContext context) {
    final color = sale.isCompleted
        ? AppColors.success
        : sale.isVoided
            ? AppColors.error
            : AppColors.warning;

    final label = sale.isCompleted
        ? 'Completed'
        : sale.isVoided
            ? 'Voided'
            : sale.status;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

// ===========================================================
// DETAIL TEXT ROW
// ===========================================================

class _DetailTextRow extends StatelessWidget {
  const _DetailTextRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),

        const SizedBox(width: 12),

        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// DETAIL AMOUNT ROW
// ===========================================================

class _DetailAmountRow extends StatelessWidget {
  const _DetailAmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.negative = false,
  });

  final String label;
  final int value;
  final bool emphasized;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: emphasized
              ? FontWeight.w800
              : FontWeight.normal,
        );

    final formattedValue = formatSleMinor(value);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style,
            ),
          ),

          Text(
            negative
                ? '− SLE $formattedValue'
                : 'SLE $formattedValue',
            style: style,
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// EMPTY AND ERROR STATE
// ===========================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 42,
              color: AppColors.textSecondary,
            ),

            const SizedBox(height: 14),

            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),

            const SizedBox(height: 8),

            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}