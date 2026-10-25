import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/state/shopflow_events.dart';
import '../../../shared/theme/app_colors.dart';
import '../services/home_dashboard_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.dashboardService});

  final HomeDashboardService? dashboardService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeDashboardService _service;

  HomeDashboardData? _dashboard;

  bool _isLoading = true;
  String? _errorMessage;

  int _loadRevision = 0;

  @override
  void initState() {
    super.initState();

    _service = widget.dashboardService ?? HomeDashboardService();

    ShopFlowEvents.dataRevision.addListener(_handleDataChanged);

    _loadDashboard();
  }

  @override
  void dispose() {
    ShopFlowEvents.dataRevision.removeListener(_handleDataChanged);

    super.dispose();
  }

  // =========================================================
  // DATA
  // =========================================================

  void _handleDataChanged() {
    if (!mounted) return;

    unawaited(_loadDashboard(silent: true));
  }

  Future<void> _loadDashboard({bool silent = false}) async {
    if (!mounted) return;

    final revision = ++_loadRevision;

    setState(() {
      if (!silent || _dashboard == null) {
        _isLoading = true;
      }

      _errorMessage = null;
    });

    try {
      final dashboard = await _service.loadDashboard();

      if (!mounted || revision != _loadRevision) return;

      setState(() {
        _dashboard = dashboard;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Dashboard loading failed: '
        '$error\n$stackTrace',
      );

      if (!mounted || revision != _loadRevision) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error is HomeDashboardServiceException
            ? error.message
            : 'Could not load the dashboard. '
                'Please check your connection and try again.';
      });
    }
  }

  // =========================================================
  // FORMATTERS
  // =========================================================

  String _formatMoney(int minorUnits) {
    final negative = minorUnits < 0;
    final amount = minorUnits.abs();

    final whole = amount ~/ 100;
    final decimal = (amount % 100).toString().padLeft(2, '0');

    final formattedWhole = whole.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );

    return 'SLE ${negative ? '-' : ''}$formattedWhole.$decimal';
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _formatSaleDate(DateTime date) {
    final localDate = date.toLocal();

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

    final day = localDate.day.toString().padLeft(2, '0');
    final month = months[localDate.month - 1];
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');

    return '$day $month · $hour:$minute';
  }

  // =========================================================
  // MAIN SCREEN
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final dashboard = _dashboard;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: AppColors.brand,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 112),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),

                const SizedBox(height: 28),

                _buildSectionHeading(
                  'TODAY',
                  subtitle: 'Your sales at a glance',
                ),

                const SizedBox(height: 12),

                // FIX: Align the metric panels at the top.
                // Do not stretch vertically inside the scroll view.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _MetricPanel(
                        label: "Today's sales",
                        value: dashboard == null
                            ? '—'
                            : _formatMoney(dashboard.todaySalesMinor),
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricPanel(
                        label: 'Transactions',
                        value: dashboard == null
                            ? '—'
                            : dashboard.todayTransactionCount.toString(),
                        icon: Icons.receipt_long_outlined,
                      ),
                    ),
                  ],
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorPanel(),
                ],

                const SizedBox(height: 28),

                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 680) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildLowStockSection(dashboard)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildRecentSalesSection(dashboard)),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLowStockSection(dashboard),
                        const SizedBox(height: 28),
                        _buildRecentSalesSection(dashboard),
                      ],
                    );
                  },
                ),

                if (_isLoading && dashboard != null) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.brand,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ShopFlow Command Centre',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your business, one place.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Refresh dashboard',
          onPressed: _isLoading ? null : _loadDashboard,
          color: AppColors.brand,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  // =========================================================
  // SECTION HEADING
  // =========================================================

  Widget _buildSectionHeading(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }

  // =========================================================
  // LOW STOCK
  // =========================================================

  Widget _buildLowStockSection(HomeDashboardData? dashboard) {
    final items = dashboard?.lowStockItems ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeading(
          'LOW STOCK',
          subtitle: 'Products that need attention',
        ),
        const SizedBox(height: 12),
        _DashboardPanel(
          child: _isLoading && dashboard == null
              ? const _PanelLoadingState()
              : dashboard == null
                  ? const _PanelEmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Stock unavailable',
                      message:
                          'Refresh the dashboard to retrieve inventory.',
                    )
                  : items.isEmpty
                      ? const _PanelEmptyState(
                          icon: Icons.check_circle_outline_rounded,
                          title: 'Stock looks good',
                          message:
                              'No active products are at or below '
                              'their reorder thresholds.',
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < items.length && i < 5; i++) ...[
                              _LowStockRow(
                                name: items[i].name,
                                quantity: items[i].quantity,
                                unit: items[i].unit,
                                isOutOfStock: items[i].isOutOfStock,
                                formatQuantity: _formatQuantity,
                              ),
                              if (i < items.length - 1 && i < 4)
                                const Divider(
                                  height: 20,
                                  color: AppColors.divider,
                                ),
                            ],
                            if (items.length > 5) ...[
                              const Divider(
                                height: 20,
                                color: AppColors.divider,
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${items.length - 5} more products need attention.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
        ),
      ],
    );
  }

  // =========================================================
  // RECENT SALES
  // =========================================================

  Widget _buildRecentSalesSection(HomeDashboardData? dashboard) {
    final sales = dashboard?.recentSales ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeading(
          'RECENT SALES',
          subtitle: 'Your latest completed transactions',
        ),
        const SizedBox(height: 12),
        _DashboardPanel(
          child: _isLoading && dashboard == null
              ? const _PanelLoadingState()
              : dashboard == null
                  ? const _PanelEmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Sales unavailable',
                      message: 'Refresh the dashboard to retrieve sales.',
                    )
                  : sales.isEmpty
                      ? const _PanelEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No sales yet',
                          message:
                              'Completed transactions will appear here '
                              'when you start selling.',
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < sales.length; i++) ...[
                              _RecentSaleRow(
                                saleNumber: sales[i].saleNumber,
                                date: _formatSaleDate(sales[i].createdAt),
                                amount: _formatMoney(sales[i].totalMinor),
                              ),
                              if (i < sales.length - 1)
                                const Divider(
                                  height: 20,
                                  color: AppColors.divider,
                                ),
                            ],
                          ],
                        ),
        ),
      ],
    );
  }

  // =========================================================
  // ERROR PANEL
  // =========================================================

  Widget _buildErrorPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 21,
            color: AppColors.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _isLoading ? null : _loadDashboard,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// METRIC PANEL
// ===========================================================

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: AppColors.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// DASHBOARD PANEL
// ===========================================================

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

// ===========================================================
// LOW STOCK ROW
// ===========================================================

class _LowStockRow extends StatelessWidget {
  const _LowStockRow({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.isOutOfStock,
    required this.formatQuantity,
  });

  final String name;
  final double quantity;
  final String unit;
  final bool isOutOfStock;
  final String Function(double) formatQuantity;

  @override
  Widget build(BuildContext context) {
    final statusColor = isOutOfStock ? AppColors.error : AppColors.warning;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isOutOfStock
                ? Icons.remove_shopping_cart_outlined
                : Icons.warning_amber_rounded,
            color: statusColor,
            size: 19,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                isOutOfStock ? 'Out of stock' : 'Low stock',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${formatQuantity(quantity)}'
          '${unit.isNotEmpty ? ' $unit' : ''}',
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// RECENT SALE ROW
// ===========================================================

class _RecentSaleRow extends StatelessWidget {
  const _RecentSaleRow({
    required this.saleNumber,
    required this.date,
    required this.amount,
  });

  final String saleNumber;
  final String date;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.receipt_long_outlined,
            color: AppColors.brand,
            size: 19,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                saleNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                date,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            amount,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// PANEL LOADING STATE
// ===========================================================

class _PanelLoadingState extends StatelessWidget {
  const _PanelLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.brand,
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// PANEL EMPTY STATE
// ===========================================================

class _PanelEmptyState extends StatelessWidget {
  const _PanelEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 29, color: AppColors.brand),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }
}