import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/state/shopflow_events.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/shopflow_page_layout.dart';
import '../data/inventory_repository.dart';
import '../models/inventory_item.dart';
import '../services/inventory_service.dart';
import 'stock_adjustment_dialog.dart';

/// ShopFlow inventory workspace.
///
/// Responsibilities:
/// - Display inventory and stock status.
/// - Search products by name or SKU.
/// - Receive stock and record stock adjustments.
/// - Refresh when another feature announces a persisted change.
/// - Manage loading, saving, empty, and error states.
///
/// Database operations remain in InventoryService and its repository.
class InventoryScreen extends StatefulWidget {
  InventoryScreen({
    super.key,
    InventoryService? inventoryService,
  }) : inventoryService = inventoryService ?? InventoryService();

  final InventoryService inventoryService;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  final ScrollController _listScrollController =
      ScrollController();

  List<InventoryItem> _items = <InventoryItem>[];

  String _searchQuery = '';
  String? _errorMessage;

  bool _isLoading = true;
  bool _isMutating = false;

  /// Prevents an older network response from replacing newer data.
  int _loadRequestRevision = 0;

  @override
  void initState() {
    super.initState();

    ShopFlowEvents.dataRevision.addListener(
      _handleDataRevisionChanged,
    );

    _loadInventory();
  }

  @override
  void didUpdateWidget(covariant InventoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.inventoryService != widget.inventoryService) {
      _loadInventory();
    }
  }

  @override
  void dispose() {
    ShopFlowEvents.dataRevision.removeListener(
      _handleDataRevisionChanged,
    );

    _searchController.dispose();
    _listScrollController.dispose();

    super.dispose();
  }

  // =========================================================
  // STATE MANAGEMENT AND DATA
  // =========================================================

  /// Called when another feature announces a successfully saved change.
  ///
  /// Examples include receiving stock, completing a sale, and editing
  /// product details.
  void _handleDataRevisionChanged() {
    if (!mounted) return;

    unawaited(_loadInventory(silent: true));
  }

  /// Fetches the latest inventory from the service.
  ///
  /// Silent refreshes keep the existing list visible while refreshing.
  /// Request revisions prevent stale responses from overwriting newer ones.
  Future<void> _loadInventory({
    bool silent = false,
  }) async {
    if (!mounted) return;

    final requestRevision = ++_loadRequestRevision;

    setState(() {
      if (!silent || _items.isEmpty) {
        _isLoading = true;
      }

      _errorMessage = null;
    });

    try {
      final items = await widget.inventoryService.getInventory();

      if (!mounted || requestRevision != _loadRequestRevision) {
        return;
      }

      setState(() {
        _items = items;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Loading inventory failed: '
        '$error\n$stackTrace',
      );

      if (!mounted || requestRevision != _loadRequestRevision) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _friendlyError(error);
      });
    }
  }

  Future<void> _refreshInventory() {
    return _loadInventory(silent: true);
  }

  List<InventoryItem> get _filteredItems {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _items;
    }

    return _items.where((item) {
      final nameMatches =
          item.name.toLowerCase().contains(query);

      final skuMatches =
          item.sku?.toLowerCase().contains(query) ?? false;

      return nameMatches || skuMatches;
    }).toList();
  }

  int get _productCount => _items.length;

  int get _outOfStockCount {
    return _items.where((item) => item.isOutOfStock).length;
  }

  int get _lowStockCount {
    return _items
        .where(
          (item) => item.isLowStock && !item.isOutOfStock,
        )
        .length;
  }

  int get _healthyStockCount {
    return _items
        .where(
          (item) =>
              !item.isLowStock && !item.isOutOfStock,
        )
        .length;
  }

  // =========================================================
  // INVENTORY ACTIONS
  // =========================================================

  /// Opens the product's actions without cluttering the inventory list.
  Future<void> _openInventoryActions(
    InventoryItem item,
  ) async {
    if (_isMutating) return;

    final action = await showModalBottomSheet<_InventoryAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                item.name,
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                'Current stock: '
                '${_formatQuantity(item.quantity)} '
                '${_unitLabel(item.unit, item.quantity)}',
                style: Theme.of(sheetContext)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 18),
              _ActionSheetTile(
                icon: Icons.add_box_outlined,
                title: 'Receive stock',
                subtitle: 'Record stock delivered to your shop.',
                onTap: () {
                  Navigator.of(sheetContext).pop(
                    _InventoryAction.receive,
                  );
                },
              ),
              const SizedBox(height: 8),
              _ActionSheetTile(
                icon: Icons.tune_rounded,
                title: 'Adjust stock',
                subtitle:
                    'Correct a count, record damage, or record a return.',
                onTap: () {
                  Navigator.of(sheetContext).pop(
                    _InventoryAction.adjust,
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    switch (action) {
      case _InventoryAction.receive:
        await _openReceiveStock(item);

      case _InventoryAction.adjust:
        await _openAdjustStock(item);
    }
  }

  // =========================================================
  // RECEIVE STOCK
  // =========================================================

  Future<void> _openReceiveStock(
    InventoryItem item,
  ) async {
    if (_isMutating) return;

    final form = await showDialog<_ReceiveStockData>(
      context: context,
      builder: (_) => _ReceiveStockDialog(item: item),
    );

    if (form == null || !mounted) return;

    setState(() {
      _isMutating = true;
      _errorMessage = null;
    });

    try {
      await widget.inventoryService.receiveStock(
        productId: item.productId,
        quantityInput: form.quantity,
        reason: form.reason,
      );

      if (!mounted) return;

      // Notify subscribers only after the service succeeds.
      // The inventory listener refreshes this screen automatically.
      ShopFlowEvents.notifyDataChanged();

      _showMessage(
        'Stock received for ${item.name}.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Receiving stock failed: '
        '$error\n$stackTrace',
      );

      if (!mounted) return;

      _showMessage(
        _friendlyError(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  // =========================================================
  // STOCK ADJUSTMENTS
  // =========================================================

  Future<void> _openAdjustStock(
    InventoryItem item,
  ) async {
    if (_isMutating) return;

    final adjustment = await showDialog<StockAdjustmentData>(
      context: context,
      builder: (_) => StockAdjustmentDialog(item: item),
    );

    if (adjustment == null || !mounted) return;

    setState(() {
      _isMutating = true;
      _errorMessage = null;
    });

    try {
      await widget.inventoryService.adjustStock(
        productId: item.productId,
        movementType: adjustment.movementType,
        quantityInput: adjustment.quantity,
        reason: adjustment.reason,
      );

      if (!mounted) return;

      ShopFlowEvents.notifyDataChanged();

      _showMessage(
        'Stock adjustment recorded for ${item.name}.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Stock adjustment failed: '
        '$error\n$stackTrace',
      );

      if (!mounted) return;

      _showMessage(
        _friendlyError(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  // =========================================================
  // HELPERS
  // =========================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? AppColors.error : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _friendlyError(Object error) {
    if (error is InventoryRepositoryException ||
        error is InventoryValidationException) {
      return error.toString();
    }

    return 'We could not complete the operation. '
        'Please try again.';
  }

  String _formatQuantity(double quantity) {
    return quantity
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'\.?0+$'), '');
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

  Color _statusColor(InventoryItem item) {
    if (item.isOutOfStock) {
      return AppColors.error;
    }

    if (item.isLowStock) {
      return AppColors.warning;
    }

    return AppColors.success;
  }

  // =========================================================
  // MAIN SCREEN
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ShopFlowPageLayout(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(isPhone: isPhone),

            SizedBox(height: isPhone ? 14 : 18),

            _buildSummary(isPhone: isPhone),

            SizedBox(height: isPhone ? 14 : 18),

            _buildSearchField(),

            const SizedBox(height: 8),

            if (_isMutating ||
                (_isLoading && _items.isNotEmpty))
              const LinearProgressIndicator(
                minHeight: 2,
              ),

            if (_errorMessage != null && _items.isNotEmpty)
              _buildInlineError(),

            Expanded(
              child: _buildInventoryList(),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader({
    required bool isPhone,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventory',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                isPhone
                    ? 'Track and manage your stock.'
                    : 'Monitor stock and manage deliveries.',
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
          tooltip: 'Refresh inventory',
          visualDensity: VisualDensity.compact,
          onPressed: _isLoading || _isMutating
              ? null
              : _refreshInventory,
          icon: const Icon(Icons.refresh_rounded),
          color: AppColors.brand,
        ),
      ],
    );
  }

  // =========================================================
  // SUMMARY
  // =========================================================

  Widget _buildSummary({
    required bool isPhone,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 12 : 16,
        vertical: isPhone ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: AppColors.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              label: 'Products',
              value: '$_productCount',
              color: AppColors.textPrimary,
            ),
          ),
          _summaryDivider(),
          Expanded(
            child: _SummaryItem(
              label: 'Available',
              value: '$_healthyStockCount',
              color: AppColors.success,
            ),
          ),
          _summaryDivider(),
          Expanded(
            child: _SummaryItem(
              label: 'Low / empty',
              value: '${_lowStockCount + _outOfStockCount}',
              color: _outOfStockCount > 0
                  ? AppColors.error
                  : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppColors.divider,
    );
  }

  // =========================================================
  // SEARCH
  // =========================================================

  Widget _buildSearchField() {
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
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search products or SKU',
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
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
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
  // INLINE ERROR
  // =========================================================

  Widget _buildInlineError() {
    return Padding(
      padding: const EdgeInsets.only(
        top: 6,
        bottom: 4,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _errorMessage!,
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
          TextButton(
            onPressed: _isLoading ? null : _refreshInventory,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // INVENTORY LIST
  // =========================================================

  Widget _buildInventoryList() {
    if (_isLoading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 38,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _refreshInventory,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final items = _filteredItems;

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshInventory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 56),
            Icon(
              _items.isEmpty
                  ? Icons.inventory_2_outlined
                  : Icons.search_off_rounded,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              _items.isEmpty
                  ? 'No active products'
                  : 'No matching products',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              _items.isEmpty
                  ? 'Create a product to start managing stock.'
                  : 'Try another product name or SKU.',
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

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
      ),
      child: Scrollbar(
        controller: _listScrollController,
        interactive: true,
        child: RefreshIndicator(
          onRefresh: _refreshInventory,
          child: ListView.separated(
            controller: _listScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              top: 2,
              bottom: 24,
              right: 5,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.divider,
            ),
            itemBuilder: (context, index) {
              return _buildInventoryRow(items[index]);
            },
          ),
        ),
      ),
    );
  }

  // =========================================================
  // CLEAN TWO-LINE INVENTORY ROW
  // =========================================================

  Widget _buildInventoryRow(InventoryItem item) {
    final statusColor = _statusColor(item);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isMutating
            ? null
            : () => _openInventoryActions(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 13,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // First line: product name and quantity.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatQuantity(item.quantity),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                  ),
                ],
              ),

              const SizedBox(height: 5),

              // Second line: stock status, unit, and action indicator.
              Row(
                children: [
                  Expanded(
                    child: _StockStatusLabel(
                      label: item.stockStatus,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _unitLabel(item.unit, item.quantity),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: _isMutating
                        ? AppColors.border
                        : AppColors.textSecondary,
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
// INVENTORY ACTIONS
// ===========================================================

enum _InventoryAction {
  receive,
  adjust,
}

class _ActionSheetTile extends StatelessWidget {
  const _ActionSheetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSubtle,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 3),
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
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// STOCK STATUS
// ===========================================================

class _StockStatusLabel extends StatelessWidget {
  const _StockStatusLabel({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// SUMMARY ITEM
// ===========================================================

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
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
        const SizedBox(height: 3),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

// ===========================================================
// RECEIVE STOCK FORM DATA
// ===========================================================

class _ReceiveStockData {
  const _ReceiveStockData({
    required this.quantity,
    required this.reason,
  });

  final String quantity;
  final String reason;
}

// ===========================================================
// RECEIVE STOCK DIALOG
// ===========================================================

class _ReceiveStockDialog extends StatefulWidget {
  const _ReceiveStockDialog({
    required this.item,
  });

  final InventoryItem item;

  @override
  State<_ReceiveStockDialog> createState() =>
      _ReceiveStockDialogState();
}

class _ReceiveStockDialogState
    extends State<_ReceiveStockDialog> {
  final _formKey = GlobalKey<FormState>();

  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();

  static final RegExp _quantityInputPattern =
      RegExp(r'^\d*(?:\.\d{0,3})?$');

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();

    super.dispose();
  }

  String? _validateQuantity(String? value) {
    final input = value?.trim() ?? '';

    if (input.isEmpty) {
      return 'Enter the quantity received.';
    }

    if (!RegExp(r'^\d+(?:\.\d{1,3})?$').hasMatch(input)) {
      return 'Enter a valid quantity with up to 3 decimals.';
    }

    final quantity = double.tryParse(input);

    if (quantity == null ||
        !quantity.isFinite ||
        quantity <= 0) {
      return 'Quantity must be greater than zero.';
    }

    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      _ReceiveStockData(
        quantity: _quantityController.text.trim(),
        reason: _reasonController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return AlertDialog(
      title: const Text('Receive stock'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Current stock: '
                    '${_formatDialogQuantity(item.quantity)} '
                    '${_dialogUnitLabel(item.unit, item.quantity)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    TextInputFormatter.withFunction(
                      (oldValue, newValue) {
                        if (_quantityInputPattern
                            .hasMatch(newValue.text)) {
                          return newValue;
                        }

                        return oldValue;
                      },
                    ),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Quantity received',
                    hintText: 'e.g. 10 or 2.500',
                    suffixText: item.unit,
                  ),
                  validator: _validateQuantity,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reasonController,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason or reference (optional)',
                    hintText: 'e.g. Supplier delivery',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Confirm receipt'),
        ),
      ],
    );
  }
}

// ===========================================================
// DIALOG QUANTITY HELPERS
// ===========================================================

String _formatDialogQuantity(double quantity) {
  return quantity
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'\.?0+$'), '');
}

String _dialogUnitLabel(String unit, double quantity) {
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