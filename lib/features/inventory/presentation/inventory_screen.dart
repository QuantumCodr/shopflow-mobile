import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/theme/app_colors.dart';
import '../data/inventory_repository.dart';
import '../models/inventory_item.dart';
import '../services/inventory_service.dart';

class InventoryScreen extends StatefulWidget {
  InventoryScreen({
    super.key,
    InventoryService? inventoryService,
  }) : inventoryService =
            inventoryService ?? InventoryService();

  final InventoryService inventoryService;

  @override
  State<InventoryScreen> createState() =>
      _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  List<InventoryItem> _items = [];

  bool _isLoading = true;
  bool _isSaving = false;

  String _searchQuery = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items =
          await widget.inventoryService.getInventory();

      if (!mounted) return;

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Loading inventory failed: '
        '$error\n$stackTrace',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  List<InventoryItem> get _filteredItems {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return _items;

    return _items.where((item) {
      return item.name.toLowerCase().contains(query) ||
          (item.sku?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  int get _lowStockCount =>
      _items.where((item) => item.isLowStock).length;

  int get _outOfStockCount =>
      _items.where((item) => item.isOutOfStock).length;

  Future<void> _openReceiveStock(InventoryItem item) async {
    if (_isSaving) return;

    final form = await showDialog<_ReceiveStockData>(
      context: context,
      builder: (_) => _ReceiveStockDialog(item: item),
    );

    if (form == null || !mounted) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.inventoryService.receiveStock(
        productId: item.productId,
        quantityInput: form.quantity,
        reason: form.reason,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stock received for ${item.name}.',
          ),
        ),
      );

      await _loadInventory();
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Receiving stock failed: '
        '$error\n$stackTrace',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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

  Color _statusColor(InventoryItem item) {
    if (item.isOutOfStock) return AppColors.error;
    if (item.isLowStock) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 820,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Inventory',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Track stock and receive new deliveries.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 18),
                  _buildSummary(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search products or SKU',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isSaving || _isLoading)
                    const LinearProgressIndicator(),
                  Expanded(
                    child: _buildInventoryList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              label: 'Products',
              value: '${_items.length}',
              color: AppColors.textPrimary,
            ),
          ),
          Expanded(
            child: _SummaryItem(
              label: 'Low stock',
              value: '$_lowStockCount',
              color: AppColors.warning,
            ),
          ),
          Expanded(
            child: _SummaryItem(
              label: 'Out of stock',
              value: '$_outOfStockCount',
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryList() {
    if (_isLoading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 42,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadInventory,
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
        onRefresh: _loadInventory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 70),
            const Icon(
              Icons.inventory_2_outlined,
              size: 44,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              _items.isEmpty
                  ? 'No active products'
                  : 'No matching products',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _items.isEmpty
                  ? 'Create a product to start managing stock.'
                  : 'Try a different search.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInventory,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          top: 4,
          bottom: 24,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          color: AppColors.divider,
        ),
        itemBuilder: (context, index) {
          final item = items[index];

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 8,
            ),
            title: Text(
              item.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reorder level: '
                    '${_formatQuantity(item.reorderLevel)} '
                    '${item.unit}',
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _statusColor(item),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.stockStatus,
                        style: TextStyle(
                          color: _statusColor(item),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (item.sku != null &&
                      item.sku!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('SKU: ${item.sku}'),
                    ),
                ],
              ),
            ),
            trailing: SizedBox(
              width: 132,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_formatQuantity(item.quantity)} ${item.unit}',
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
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 32,
                    child: TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => _openReceiveStock(item),
                      child: const Text('Receive stock'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

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
        const SizedBox(height: 5),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
        ),
      ],
    );
  }
}

class _ReceiveStockData {
  const _ReceiveStockData({
    required this.quantity,
    required this.reason,
  });

  final String quantity;
  final String reason;
}

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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Current stock: '
                    '${item.quantity.toStringAsFixed(3)} '
                    '${item.unit}',
                  ),
                ),
                const SizedBox(height: 18),
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
                const SizedBox(height: 14),
                TextFormField(
                  controller: _reasonController,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason or reference (optional)',
                    hintText: 'e.g. Supplier delivery',
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