import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shopflow_mobile/features/pos/data/pos_repository.dart';

import '../../../shared/formatters/sle_money.dart';
import '../../../shared/theme/app_colors.dart';
import '../models/pos_models.dart';
import '../services/pos_service.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({
    super.key,
    this.posService,
  });

  final PosService? posService;

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  late final PosService _posService;

  final TextEditingController _searchController =
      TextEditingController();

  final Map<String, PosCartLine> _cart = {};

  List<PosCatalogItem> _catalog = [];

  bool _isLoading = true;
  bool _isProcessing = false;

  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _posService = widget.posService ?? PosService();

    _loadCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final catalog = await _posService.loadCatalog();

      if (!mounted) return;

      setState(() {
        _catalog = catalog;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: POS catalogue loading failed: '
        '$error\n$stackTrace',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _friendlyError(error);
      });
    }
  }

  List<PosCatalogItem> get _filteredCatalog {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _catalog;
    }

    return _catalog.where((item) {
      final product = item.product;

      return product.name.toLowerCase().contains(query) ||
          (product.sku?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  int get _cartQuantity {
    return _cart.values.fold<int>(
      0,
      (sum, line) => sum + line.quantity,
    );
  }

  /// All monetary calculations use minor units.
  ///
  /// For example:
  /// SLE 65.00 = 6500 minor units.
  int get _cartTotal {
    return _cart.values.fold<int>(
      0,
      (sum, line) => sum + line.lineTotal,
    );
  }

  void _addProduct(PosCatalogItem item) {
    if (_isProcessing) return;

    final product = item.product;
    final currentLine = _cart[product.id];
    final currentQuantity = currentLine?.quantity ?? 0;

    if (currentQuantity >= item.availableQuantity) {
      _showMessage(
        item.availableQuantity == 0
            ? 'This product has no recorded stock.'
            : 'You cannot add more than the available stock.',
      );
      return;
    }

    setState(() {
      _cart[product.id] = PosCartLine(
        product: product,
        quantity: currentQuantity + 1,
      );
    });
  }

  void _changeQuantity(PosCartLine line, int difference) {
    if (_isProcessing) return;

    final currentQuantity = _cart[line.product.id]?.quantity ?? 0;
    final nextQuantity = currentQuantity + difference;

    if (nextQuantity <= 0) {
      setState(() {
        _cart.remove(line.product.id);
      });
      return;
    }

    final catalogItem = _catalog.firstWhere(
      (item) => item.product.id == line.product.id,
      orElse: () => PosCatalogItem(
        product: line.product,
        availableQuantity: 0,
      ),
    );

    if (nextQuantity > catalogItem.availableQuantity) {
      _showMessage(
        'The requested quantity exceeds available stock.',
      );
      return;
    }

    setState(() {
      _cart[line.product.id] = PosCartLine(
        product: line.product,
        quantity: nextQuantity,
      );
    });
  }

  Future<void> _openCheckout() async {
    if (_cart.isEmpty || _isProcessing) return;

    final lines = _cart.values.toList();
    final total = _cartTotal;

    // The dialog returns payment in minor units.
    final paymentAmount = await showDialog<int>(
      context: context,
      builder: (_) => _CheckoutDialog(
        lines: lines,
        total: total,
      ),
    );

    if (paymentAmount == null || !mounted) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final receipt = await _posService.completeSale(
        lines: lines,
        paymentAmount: paymentAmount,
      );

      if (!mounted) return;

      setState(() {
        _cart.clear();
      });

      // Refresh stock after the database confirms the sale.
      await _loadCatalog();

      if (!mounted) return;

      await _showReceipt(receipt);
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Checkout failed: $error\n$stackTrace',
      );

      if (!mounted) return;

      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _showReceipt(PosReceipt receipt) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.success,
            size: 44,
          ),
          title: const Text('Sale completed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (receipt.saleNumber.isNotEmpty)
                Text('Receipt: ${receipt.saleNumber}'),
              const SizedBox(height: 12),
              _ReceiptRow(
                label: 'Total',
                value: 'SLE ${formatSleMinor(receipt.total)}',
              ),
              _ReceiptRow(
                label: 'Received',
                value: 'SLE ${formatSleMinor(receipt.payment)}',
              ),
              _ReceiptRow(
                label: 'Change',
                value: 'SLE ${formatSleMinor(receipt.change)}',
                emphasized: true,
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _friendlyError(Object error) {
    if (error is PosServiceException ||
        error is PosRepositoryException) {
      return error.toString();
    }

    return 'We could not complete the operation. '
        'Please check your connection and try again.';
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
                    'Point of Sale',
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
                    'Select products and complete a sale.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search products',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isProcessing || _isLoading)
                    const LinearProgressIndicator(),
                  Expanded(
                    child: _buildProductList(),
                  ),
                  _buildCartSummary(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    if (_isLoading && _catalog.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _catalog.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadCatalog,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final items = _filteredCatalog;

    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          Icon(
            _catalog.isEmpty
                ? Icons.inventory_2_outlined
                : Icons.search_off_rounded,
            size: 44,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            _catalog.isEmpty
                ? 'No active products'
                : 'No matching products',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _catalog.isEmpty
                ? 'Create a product before making a sale.'
                : 'Try a different name or SKU.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCatalog,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          color: AppColors.divider,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          final product = item.product;
          final cartQuantity = _cart[product.id]?.quantity ?? 0;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 6,
            ),
            title: Text(
              product.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Stock: ${item.availableQuantity} ${product.unit}'
              '${product.sku == null ? '' : '\nSKU: ${product.sku}'}',
            ),
            isThreeLine: product.sku != null,
            trailing: SizedBox(
              width: 145,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'SLE ${formatSleMinor(product.sellingPrice)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  if (cartQuantity > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _QuantityButton(
                          icon: Icons.remove_rounded,
                          onPressed: _isProcessing
                              ? null
                              : () => _changeQuantity(
                                    PosCartLine(
                                      product: product,
                                      quantity: cartQuantity,
                                    ),
                                    -1,
                                  ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          child: Text('$cartQuantity'),
                        ),
                        _QuantityButton(
                          icon: Icons.add_rounded,
                          onPressed: _isProcessing ||
                                  cartQuantity >= item.availableQuantity
                              ? null
                              : () => _addProduct(item),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      height: 32,
                      child: TextButton.icon(
                        onPressed: _isProcessing ||
                                item.availableQuantity <= 0
                            ? null
                            : () => _addProduct(item),
                        icon: const Icon(
                          Icons.add_rounded,
                          size: 18,
                        ),
                        label: const Text('Add'),
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

  Widget _buildCartSummary() {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 16),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(
            color: AppColors.divider,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cart · $_cartQuantity item(s)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'SLE ${formatSleMinor(_cartTotal)}',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _cart.isEmpty || _isProcessing
                ? null
                : _openCheckout,
            child: Text(
              _isProcessing ? 'Processing…' : 'Review cart',
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton.filledTonal(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight:
              emphasized ? FontWeight.w700 : FontWeight.normal,
          color: AppColors.textPrimary,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _CheckoutDialog extends StatefulWidget {
  const _CheckoutDialog({
    required this.lines,
    required this.total,
  });

  final List<PosCartLine> lines;

  /// Total in minor units, not whole SLE.
  final int total;

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  final _formKey = GlobalKey<FormState>();
  final _paymentController = TextEditingController();

  static final RegExp _amountInputPattern =
      RegExp(r'^(?:\d+(?:\.\d{0,2})?)?$');

  /// Accepts a value entered in SLE and converts it to minor units.
  int? get _paymentAmount =>
      parseSleToMinor(_paymentController.text);

  List<TextInputFormatter> get _moneyFormatters => [
        TextInputFormatter.withFunction(
          (oldValue, newValue) {
            if (_amountInputPattern.hasMatch(newValue.text)) {
              return newValue;
            }

            return oldValue;
          },
        ),
      ];

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final received = _paymentAmount;

    return AlertDialog(
      title: const Text('Complete sale'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...widget.lines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${line.product.name} × ${line.quantity}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'SLE ${formatSleMinor(line.lineTotal)}',
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),
                _ReceiptRow(
                  label: 'Total due',
                  value: 'SLE ${formatSleMinor(widget.total)}',
                  emphasized: true,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _paymentController,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _moneyFormatters,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Amount received (SLE)',
                    prefixText: 'SLE ',
                    hintText: 'e.g. 100.00',
                  ),
                  validator: (value) {
                    final payment = parseSleToMinor(value ?? '');

                    if (payment == null) {
                      return 'Enter a valid amount, e.g. 100.00.';
                    }

                    if (payment < widget.total) {
                      return 'Payment must cover the total due.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (received != null && received >= widget.total)
                  _ReceiptRow(
                    label: 'Change due',
                    value:
                        'SLE ${formatSleMinor(received - widget.total)}',
                    emphasized: true,
                  )
                else
                  Text(
                    'Enter at least SLE '
                    '${formatSleMinor(widget.total)}.',
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;

            final amount = _paymentAmount;

            if (amount == null) return;

            // Return the amount in minor units to the POS service.
            Navigator.of(context).pop(amount);
          },
          child: const Text('Complete sale'),
        ),
      ],
    );
  }
}