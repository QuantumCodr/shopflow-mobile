import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/state/shopflow_events.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/shopflow_page_layout.dart';
import '../models/stock_movement_model.dart';
import '../services/stock_movement_service.dart';

enum _MovementFilter {
  all,
  stockIn,
  stockOut,
}

class StockMovementScreen extends StatefulWidget {
  const StockMovementScreen({
    super.key,
    this.stockMovementService,
  });

  final StockMovementService? stockMovementService;

  @override
  State<StockMovementScreen> createState() =>
      _StockMovementScreenState();
}

class _StockMovementScreenState
    extends State<StockMovementScreen> {
  late final StockMovementService _service;

  final TextEditingController _searchController =
      TextEditingController();

  List<StockMovement> _movements = [];

  bool _isLoading = true;

  String? _errorMessage;
  String _searchQuery = '';

  _MovementFilter _filter = _MovementFilter.all;

  int _loadRevision = 0;

  @override
  void initState() {
    super.initState();

    _service =
        widget.stockMovementService ?? StockMovementService();

    ShopFlowEvents.dataRevision.addListener(
      _handleDataChanged,
    );

    _loadMovements();
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

    unawaited(_loadMovements(silent: true));
  }

  Future<void> _loadMovements({
    bool silent = false,
  }) async {
    if (!mounted) return;

    final revision = ++_loadRevision;

    setState(() {
      if (!silent || _movements.isEmpty) {
        _isLoading = true;
      }

      _errorMessage = null;
    });

    try {
      final movements =
          await _service.getRecentMovements();

      if (!mounted || revision != _loadRevision) {
        return;
      }

      setState(() {
        _movements = movements;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Stock history loading failed: '
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

  List<StockMovement> get _filteredMovements {
    final query = _searchQuery.trim().toLowerCase();

    return _movements.where((movement) {
      final matchesFilter = switch (_filter) {
        _MovementFilter.all => true,
        _MovementFilter.stockIn => movement.isStockIn,
        _MovementFilter.stockOut => movement.isStockOut,
      };

      if (!matchesFilter) return false;

      if (query.isEmpty) return true;

      final searchableText = [
        movement.productName,
        movement.productId,
        _movementTypeLabel(movement.movementType),
        movement.movementType,
        movement.reason ?? '',
        movement.referenceId ?? '',
      ].join(' ').toLowerCase();

      return searchableText.contains(query);
    }).toList(growable: false);
  }

  int get _stockInCount {
    return _movements
        .where((movement) => movement.isStockIn)
        .length;
  }

  int get _stockOutCount {
    return _movements
        .where((movement) => movement.isStockOut)
        .length;
  }

  // =========================================================
  // OPEN MOVEMENT DETAILS
  // =========================================================

  Future<void> _openMovementDetails(
    StockMovement movement,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.68,
          minChildSize: 0.42,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            final isIncoming = movement.isStockIn;

            final movementColor = isIncoming
                ? AppColors.success
                : movement.isStockOut
                    ? AppColors.error
                    : AppColors.textSecondary;

            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Drag handle.
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(
                        top: 10,
                        bottom: 6,
                      ),
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),

                  // Header.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      10,
                      12,
                      16,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: movementColor.withValues(
                              alpha: 0.09,
                            ),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            isIncoming
                                ? Icons.south_west_rounded
                                : movement.isStockOut
                                    ? Icons.north_east_rounded
                                    : Icons.swap_vert_rounded,
                            color: movementColor,
                            size: 24,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Movement Details',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color:
                                          AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                movement.productName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          tooltip: 'Close details',
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(
                    height: 1,
                    color: AppColors.divider,
                  ),

                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Quantity summary.
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                _movementTypeLabel(
                                  movement.movementType,
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color:
                                          AppColors.textSecondary,
                                    ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                _formatSignedQuantity(movement),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: movementColor,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                              ),

                              const SizedBox(height: 6),

                              Text(
                                _formatDateTime(
                                  movement.createdAt,
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'Movement information',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),

                        const SizedBox(height: 14),

                        _DetailTextRow(
                          label: 'Product',
                          value: movement.productName,
                        ),

                        const SizedBox(height: 14),

                        _DetailTextRow(
                          label: 'Movement type',
                          value: _movementTypeLabel(
                            movement.movementType,
                          ),
                        ),

                        const SizedBox(height: 14),

                        _DetailTextRow(
                          label: 'Quantity change',
                          value: _formatSignedQuantity(movement),
                          valueColor: movementColor,
                        ),

                        const SizedBox(height: 14),

                        _DetailTextRow(
                          label: 'Recorded date',
                          value: _formatDateTime(
                            movement.createdAt,
                          ),
                        ),

                        const SizedBox(height: 14),

                        _DetailTextRow(
                          label: 'Reason',
                          value: _cleanReason(movement.reason),
                        ),

                        if (movement.referenceId != null) ...[
                          const SizedBox(height: 14),

                          const Divider(
                            color: AppColors.divider,
                          ),

                          const SizedBox(height: 14),

                          Text(
                            'Reference ID',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color:
                                      AppColors.textSecondary,
                                ),
                          ),

                          const SizedBox(height: 5),

                          SelectableText(
                            movement.referenceId!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color:
                                      AppColors.textPrimary,
                                ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                            },
                            child: const Text('Close details'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================
  // FORMATTERS
  // =========================================================

  String _movementTypeLabel(String movementType) {
    switch (movementType) {
      case 'opening_stock':
        return 'Opening stock';
      case 'stock_in':
        return 'Stock received';
      case 'sale':
        return 'Sale';
      case 'adjustment_in':
        return 'Stock adjustment in';
      case 'adjustment_out':
        return 'Stock adjustment out';
      case 'damaged':
        return 'Damaged stock';
      case 'returned':
        return 'Returned stock';
      default:
        return movementType
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
            )
            .join(' ');
    }
  }

  String _formatSignedQuantity(
    StockMovement movement,
  ) {
    final quantity = movement.quantityDelta.abs();

    final formattedQuantity = quantity == quantity.truncateToDouble()
        ? quantity.toInt().toString()
        : quantity
            .toStringAsFixed(3)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');

    final sign = movement.quantityDelta > 0
        ? '+'
        : movement.quantityDelta < 0
            ? '−'
            : '';

    return '$sign$formattedQuantity '
        '${_unitLabel(movement.productUnit, quantity)}';
  }

  String _unitLabel(
    String unit,
    double quantity,
  ) {
    final singular = quantity == 1;

    switch (unit) {
      case 'piece':
        return singular ? 'piece' : 'pieces';
      case 'pack':
        return singular ? 'pack' : 'packs';
      case 'bottle':
        return singular ? 'bottle' : 'bottles';
      case 'box':
        return singular ? 'box' : 'boxes';
      case 'bag':
        return singular ? 'bag' : 'bags';
      case 'litre':
        return singular ? 'litre' : 'litres';
      case 'kg':
        return 'kg';
      case 'g':
        return 'g';
      case 'ml':
        return 'ml';
      default:
        return unit;
    }
  }

  String _cleanReason(String? reason) {
    final value = reason?.trim();

    if (value == null || value.isEmpty) {
      return 'No reason recorded';
    }

    return value;
  }

  String _formatDateTime(DateTime value) {
    final date = value.toLocal();
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final movementDay = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final difference = today.difference(movementDay).inDays;

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

  String _friendlyError(Object error) {
    if (error is StockMovementServiceException) {
      return error.toString();
    }

    return 'We could not load stock history. '
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

            if (_errorMessage != null &&
                _movements.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildInlineError(),
            ],

            if (_isLoading && _movements.isNotEmpty)
              const LinearProgressIndicator(
                minHeight: 2,
              ),

            const SizedBox(height: 6),

            Expanded(
              child: _buildMovementList(),
            ),
          ],
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
                'Stock History',
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
                'Track stock receipts, sales and adjustments.',
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
          tooltip: 'Refresh stock history',
          onPressed: _isLoading
              ? null
              : () => _loadMovements(),
          color: AppColors.brand,
          icon: const Icon(
            Icons.refresh_rounded,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // SUMMARY
  // =========================================================

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
              label: 'Loaded movements',
              value: '${_movements.length}',
              icon: Icons.swap_vert_rounded,
            ),
          ),

          Container(
            width: 1,
            height: 42,
            color: AppColors.divider,
          ),

          Expanded(
            child: _SummaryMetric(
              label: 'Stock in',
              value: '$_stockInCount',
              icon: Icons.south_west_rounded,
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
              label: 'Stock out',
              value: '$_stockOutCount',
              icon: Icons.north_east_rounded,
              valueColor: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SEARCH
  // =========================================================

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
          hintText: 'Search product, movement or reason',
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

  // =========================================================
  // FILTERS
  // =========================================================

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            label: 'All',
            value: _MovementFilter.all,
          ),

          const SizedBox(width: 8),

          _buildFilterChip(
            label: 'Stock In',
            value: _MovementFilter.stockIn,
          ),

          const SizedBox(width: 8),

          _buildFilterChip(
            label: 'Stock Out',
            value: _MovementFilter.stockOut,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required _MovementFilter value,
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
      selectedColor: AppColors.brand.withValues(
        alpha: 0.12,
      ),
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

  // =========================================================
  // INLINE ERROR
  // =========================================================

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
              'Refresh failed. Showing loaded movements.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
          ),

          TextButton(
            onPressed: _isLoading
                ? null
                : () => _loadMovements(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MOVEMENT LIST
  // =========================================================

  Widget _buildMovementList() {
    if (_isLoading && _movements.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _movements.isEmpty) {
      return _EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load stock history',
        message: _errorMessage!,
        onRetry: () => _loadMovements(),
      );
    }

    final movements = _filteredMovements;

    if (movements.isEmpty) {
      final hasMovements = _movements.isNotEmpty;

      return RefreshIndicator(
        onRefresh: _loadMovements,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 60),

            Icon(
              hasMovements
                  ? Icons.search_off_rounded
                  : Icons.swap_vert_rounded,
              size: 42,
              color: AppColors.textSecondary,
            ),

            const SizedBox(height: 14),

            Text(
              hasMovements
                  ? 'No matching movements'
                  : 'No stock movements recorded',
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
              hasMovements
                  ? 'Try another search or filter.'
                  : 'Stock receipts, sales and adjustments '
                      'will appear here.',
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
      onRefresh: _loadMovements,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          bottom: 16,
        ),
        itemCount: movements.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          color: AppColors.divider,
        ),
        itemBuilder: (context, index) {
          return _buildMovementRow(movements[index]);
        },
      ),
    );
  }

  // =========================================================
  // MOVEMENT ROW
  // =========================================================

  Widget _buildMovementRow(
    StockMovement movement,
  ) {
    final color = movement.isStockIn
        ? AppColors.success
        : movement.isStockOut
            ? AppColors.error
            : AppColors.textSecondary;

    final icon = movement.isStockIn
        ? Icons.south_west_rounded
        : movement.isStockOut
            ? Icons.north_east_rounded
            : Icons.swap_vert_rounded;

    final reason = movement.reason?.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openMovementDetails(movement),
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 13,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 21,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movement.productName,
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
                      '${_movementTypeLabel(movement.movementType)}'
                      ' · ${_formatDateTime(movement.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),

                    if (reason != null && reason.isNotEmpty) ...[
                      const SizedBox(height: 4),

                      Text(
                        reason,
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
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatSignedQuantity(movement),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                  ),

                  const SizedBox(height: 5),

                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
            maxLines: 2,
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
// DETAIL TEXT ROW
// ===========================================================

class _DetailTextRow extends StatelessWidget {
  const _DetailTextRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// EMPTY STATE
// ===========================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

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
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}