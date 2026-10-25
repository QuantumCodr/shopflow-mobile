import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/state/shopflow_events.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/shopflow_page_layout.dart';
import '../models/report_models.dart';
import '../services/reports_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    this.reportsService,
  });

  final ReportsService? reportsService;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final ReportsService _service;

  ReportsPeriod _period = ReportsPeriod.last7Days;

  ReportsSnapshot? _report;

  bool _isLoading = true;
  String? _errorMessage;

  int _loadRevision = 0;

  @override
  void initState() {
    super.initState();

    _service = widget.reportsService ?? ReportsService();

    ShopFlowEvents.dataRevision.addListener(_handleDataChanged);

    _loadReports();
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

    unawaited(_loadReports(silent: true));
  }

  Future<void> _loadReports({
    bool silent = false,
  }) async {
    if (!mounted) return;

    final revision = ++_loadRevision;
    final requestedPeriod = _period;

    setState(() {
      if (!silent || _report == null) {
        _isLoading = true;
      }

      _errorMessage = null;
    });

    try {
      final report = await _service.loadReports(
        period: requestedPeriod,
      );

      if (!mounted || revision != _loadRevision) return;

      setState(() {
        _report = report;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Reports loading failed: '
        '$error\n$stackTrace',
      );

      if (!mounted || revision != _loadRevision) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error is ReportsServiceException
            ? error.message
            : 'Could not load reports. '
                'Please check your connection and try again.';
      });
    }
  }

  void _changePeriod(ReportsPeriod period) {
    if (period == _period || _isLoading) return;

    setState(() {
      _period = period;
    });

    unawaited(_loadReports());
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

  String _formatDate(DateTime date) {
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

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatRange(ReportsSnapshot report) {
    final lastIncludedDay = report.endExclusive.subtract(
      const Duration(days: 1),
    );

    if (report.startInclusive.year == lastIncludedDay.year &&
        report.startInclusive.month == lastIncludedDay.month &&
        report.startInclusive.day == lastIncludedDay.day) {
      return _formatDate(report.startInclusive);
    }

    return '${_formatDate(report.startInclusive)}'
        ' – ${_formatDate(lastIncludedDay)}';
  }

  // =========================================================
  // MAIN SCREEN
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ShopFlowPageLayout(
        child: RefreshIndicator(
          onRefresh: _loadReports,
          color: AppColors.brand,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              top: 24,
              bottom: 100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),

                const SizedBox(height: 24),

                _buildPeriodSelector(),

                if (report != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _formatRange(report),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorPanel(),
                ],

                if (_isLoading && report == null) ...[
                  const SizedBox(height: 32),
                  const _ReportsLoadingState(),
                ] else if (report != null) ...[
                  const SizedBox(height: 24),

                  _buildSectionHeading(
                    'SALES PERFORMANCE',
                    subtitle: 'Completed sales for the selected period',
                  ),

                  const SizedBox(height: 12),

                  _buildSalesMetrics(report),

                  const SizedBox(height: 28),

                  _buildSectionHeading(
                    'SALES TREND',
                    subtitle: 'Daily completed sales',
                  ),

                  const SizedBox(height: 12),

                  _buildSalesTrend(report),

                  const SizedBox(height: 28),

                  _buildSectionHeading(
                    'INVENTORY OVERVIEW',
                    subtitle: 'Current active product inventory',
                  ),

                  const SizedBox(height: 12),

                  _buildInventoryMetrics(report),

                  const SizedBox(height: 28),

                  _buildSectionHeading(
                    'STOCK NEEDING ATTENTION',
                    subtitle: 'Products at or below their reorder levels',
                  ),

                  const SizedBox(height: 12),

                  _buildStockAttention(report),
                ],

                if (_isLoading && report != null) ...[
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
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reports',
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
                'Understand your sales and stock performance.',
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
          tooltip: 'Refresh reports',
          onPressed: _isLoading ? null : _loadReports,
          color: AppColors.brand,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  // =========================================================
  // PERIOD SELECTOR
  // =========================================================

  Widget _buildPeriodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ReportsPeriod.values.map((period) {
          final selected = period == _period;

          return Padding(
            padding: EdgeInsets.only(
              right: period == ReportsPeriod.values.last ? 0 : 8,
            ),
            child: ChoiceChip(
              label: Text(period.label),
              selected: selected,
              showCheckmark: false,
              onSelected: _isLoading
                  ? null
                  : (_) => _changePeriod(period),
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.brand.withValues(alpha: 0.10),
              side: BorderSide(
                color: selected
                    ? AppColors.brand.withValues(alpha: 0.45)
                    : AppColors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              labelStyle: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(
                    color: selected
                        ? AppColors.brand
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  // =========================================================
  // SECTION HEADING
  // =========================================================

  Widget _buildSectionHeading(
    String title, {
    String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ],
    );
  }

  // =========================================================
  // SALES METRICS
  // =========================================================

  Widget _buildSalesMetrics(ReportsSnapshot report) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;

        final columns = constraints.maxWidth >= 680 ? 3 : 2;

        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) /
                columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: _ReportMetric(
                label: 'Total sales',
                value: _formatMoney(report.totalSalesMinor),
                icon: Icons.payments_outlined,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _ReportMetric(
                label: 'Transactions',
                value: report.transactionCount.toString(),
                icon: Icons.receipt_long_outlined,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _ReportMetric(
                label: 'Average sale',
                value: _formatMoney(
                  report.averageTransactionMinor,
                ),
                icon: Icons.calculate_outlined,
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // SALES TREND
  // =========================================================

  Widget _buildSalesTrend(ReportsSnapshot report) {
    return _ReportPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sales by day',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Completed sales',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 160,
            width: double.infinity,
            child: CustomPaint(
              painter: _SalesTrendPainter(
                points: report.dailySales,
              ),
            ),
          ),

          const SizedBox(height: 10),

          _buildChartDateLabels(report.dailySales),

          const SizedBox(height: 20),

          const Divider(
            height: 1,
            color: AppColors.divider,
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _TrendSummary(
                  label: 'Best sales day',
                  value: _formatMoney(
                    _highestSalesDay(report.dailySales).salesMinor,
                  ),
                  detail: _formatDate(
                    _highestSalesDay(report.dailySales).date,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _TrendSummary(
                  label: 'Active sales days',
                  value: report.dailySales
                      .where((day) => day.transactionCount > 0)
                      .length
                      .toString(),
                  detail: 'Days with transactions',
                ),
              ),
            ],
          ),

          if (report.transactionCount == 0) ...[
            const SizedBox(height: 14),
            const _InlineNotice(
              message:
                  'No completed sales were recorded during this period.',
            ),
          ],
        ],
      ),
    );
  }

  DailySalesPoint _highestSalesDay(
    List<DailySalesPoint> points,
  ) {
    if (points.isEmpty) {
      return DailySalesPoint(
        date: DateTime.now(),
        salesMinor: 0,
        transactionCount: 0,
      );
    }

    return points.reduce(
      (a, b) => a.salesMinor >= b.salesMinor ? a : b,
    );
  }

  Widget _buildChartDateLabels(
    List<DailySalesPoint> points,
  ) {
    if (points.isEmpty) return const SizedBox.shrink();

    final indexes = <int>[];

    final step = points.length <= 7
        ? 1
        : (points.length / 6).ceil();

    for (var i = 0; i < points.length; i += step) {
      indexes.add(i);
    }

    if (indexes.last != points.length - 1) {
      indexes.add(points.length - 1);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: indexes.map((index) {
        final date = points[index].date;

        final label = points.length > 10
            ? '${date.day}/${date.month}'
            : '${date.day}';

        return Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(
                color: AppColors.textSecondary,
              ),
        );
      }).toList(growable: false),
    );
  }

  // =========================================================
  // INVENTORY METRICS
  // =========================================================

  Widget _buildInventoryMetrics(ReportsSnapshot report) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;

        final columns = constraints.maxWidth >= 680 ? 3 : 2;

        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) /
                columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: _ReportMetric(
                label: 'Active products',
                value: report.activeProductCount.toString(),
                icon: Icons.inventory_2_outlined,
                accent: AppColors.brand,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _ReportMetric(
                label: 'Low stock',
                value: report.lowStockCount.toString(),
                icon: Icons.warning_amber_rounded,
                accent: report.lowStockCount > 0
                    ? AppColors.warning
                    : AppColors.success,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _ReportMetric(
                label: 'Out of stock',
                value: report.outOfStockCount.toString(),
                icon: Icons.remove_shopping_cart_outlined,
                accent: report.outOfStockCount > 0
                    ? AppColors.error
                    : AppColors.success,
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // STOCK ATTENTION
  // =========================================================

  Widget _buildStockAttention(ReportsSnapshot report) {
    final items = report.stockAttentionItems.take(10).toList();

    return _ReportPanel(
      child: items.isEmpty
          ? const _ReportEmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'Inventory is in good shape',
              message:
                  'No active products are currently below their '
                  'reorder levels or out of stock.',
            )
          : Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _StockAttentionRow(
                    name: items[i].name,
                    sku: items[i].sku,
                    quantity: items[i].quantity,
                    unit: items[i].unit,
                    isOutOfStock: items[i].isOutOfStock,
                    formatQuantity: _formatQuantity,
                  ),
                  if (i < items.length - 1)
                    const Divider(
                      height: 20,
                      color: AppColors.divider,
                    ),
                ],
                if (report.stockAttentionItems.length > items.length) ...[
                  const Divider(
                    height: 20,
                    color: AppColors.divider,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${report.stockAttentionItems.length - items.length} '
                      'additional products need attention.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                ],
              ],
            ),
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
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.2),
        ),
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
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _isLoading ? null : _loadReports,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// REPORT METRIC
// ===========================================================

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = AppColors.brand,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 116,
      ),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
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
// REPORT PANEL
// ===========================================================

class _ReportPanel extends StatelessWidget {
  const _ReportPanel({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: child,
    );
  }
}

// ===========================================================
// SALES TREND SUMMARY
// ===========================================================

class _TrendSummary extends StatelessWidget {
  const _TrendSummary({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

// ===========================================================
// STOCK ATTENTION ROW
// ===========================================================

class _StockAttentionRow extends StatelessWidget {
  const _StockAttentionRow({
    required this.name,
    required this.sku,
    required this.quantity,
    required this.unit,
    required this.isOutOfStock,
    required this.formatQuantity,
  });

  final String name;
  final String? sku;
  final double quantity;
  final String unit;
  final bool isOutOfStock;
  final String Function(double) formatQuantity;

  @override
  Widget build(BuildContext context) {
    final accent =
        isOutOfStock ? AppColors.error : AppColors.warning;

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            isOutOfStock
                ? Icons.remove_shopping_cart_outlined
                : Icons.warning_amber_rounded,
            size: 20,
            color: accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              if (sku != null && sku!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  'SKU $sku',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
              const SizedBox(height: 3),
              Text(
                isOutOfStock ? 'Out of stock' : 'Low stock',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${formatQuantity(quantity)}'
          '${unit.isNotEmpty ? ' $unit' : ''}',
          textAlign: TextAlign.end,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

// ===========================================================
// SALES TREND CHART
// ===========================================================

class _SalesTrendPainter extends CustomPainter {
  const _SalesTrendPainter({
    required this.points,
  });

  final List<DailySalesPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    const topPadding = 8.0;
    const bottomPadding = 8.0;

    final plotHeight = size.height - topPadding - bottomPadding;
    final baseline = size.height - bottomPadding;

    final gridPaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;

    // Four horizontal grid lines.
    for (var i = 0; i < 4; i++) {
      final y = topPadding + plotHeight * (i / 3);

      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    final maxSales = points.fold<int>(
      0,
      (maximum, point) =>
          point.salesMinor > maximum
              ? point.salesMinor
              : maximum,
    );

    if (maxSales <= 0) return;

    final slotWidth = size.width / points.length;
    final barWidth = math.min(24.0, slotWidth * 0.62);

    final barPaint = Paint()
      ..color = AppColors.brand
      ..style = PaintingStyle.fill;

    for (var i = 0; i < points.length; i++) {
      final value = points[i].salesMinor;

      if (value <= 0) continue;

      final barHeight =
          (value / maxSales) * (plotHeight * 0.92);

      final left = (i * slotWidth) +
          ((slotWidth - barWidth) / 2);

      final rect = Rect.fromLTWH(
        left,
        baseline - barHeight,
        barWidth,
        barHeight,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          const Radius.circular(4),
        ),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SalesTrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

// ===========================================================
// LOADING STATE
// ===========================================================

class _ReportsLoadingState extends StatelessWidget {
  const _ReportsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.brand,
              ),
            ),
            SizedBox(height: 16),
            Text('Preparing your reports...'),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// EMPTY STATE
// ===========================================================

class _ReportEmptyState extends StatelessWidget {
  const _ReportEmptyState({
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
      padding: const EdgeInsets.symmetric(
        vertical: 20,
        horizontal: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 32,
            color: AppColors.brand,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// INLINE NOTICE
// ===========================================================

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}