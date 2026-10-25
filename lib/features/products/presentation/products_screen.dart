import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/formatters/sle_money.dart';
import '../../../shared/state/shopflow_events.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/shopflow_page_layout.dart';
import '../data/product_repository.dart';
import '../models/product.dart';
import '../services/product_service.dart';

/// ShopFlow product catalogue.
///
/// Responsibilities:
/// - Display active products.
/// - Search by product name or SKU.
/// - Create and edit products.
/// - Deactivate products without deleting historical records.
/// - Automatically refresh when application data changes.
/// - Preserve existing results during background refreshes.
///
/// Data access and business rules remain in ProductService
/// and ProductRepository.
class ProductsScreen extends StatefulWidget {
  ProductsScreen({
    super.key,
    ProductService? productService,
  }) : productService = productService ?? ProductService();

  final ProductService productService;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  List<Product> _products = [];

  String _searchQuery = '';
  String? _errorMessage;

  bool _isLoading = true;
  bool _isSaving = false;

  /// Prevents an older request from overwriting newer results.
  int _loadRequestRevision = 0;

  @override
  void initState() {
    super.initState();

    ShopFlowEvents.dataRevision.addListener(
      _handleDataRevisionChanged,
    );

    _loadProducts();
  }

  @override
  void didUpdateWidget(covariant ProductsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.productService != widget.productService) {
      _loadProducts();
    }
  }

  @override
  void dispose() {
    ShopFlowEvents.dataRevision.removeListener(
      _handleDataRevisionChanged,
    );

    _searchController.dispose();

    super.dispose();
  }

  // =========================================================
  // STATE MANAGEMENT AND DATA
  // =========================================================

  /// Refreshes the catalogue when another feature announces
  /// a successfully persisted change.
  ///
  /// Examples:
  /// - Inventory receives stock.
  /// - Inventory adjusts stock.
  /// - POS completes a sale.
  /// - Another screen creates or updates a product.
  void _handleDataRevisionChanged() {
    if (!mounted) return;

    unawaited(_loadProducts(silent: true));
  }

  /// Retrieves active products from the existing service.
  ///
  /// Silent refreshes preserve the visible catalogue while the
  /// latest data is being requested.
  Future<void> _loadProducts({
    bool silent = false,
  }) async {
    if (!mounted) return;

    final requestRevision = ++_loadRequestRevision;

    setState(() {
      if (!silent || _products.isEmpty) {
        _isLoading = true;
      }

      _errorMessage = null;
    });

    try {
      final products =
          await widget.productService.getActiveProducts();

      if (!mounted ||
          requestRevision != _loadRequestRevision) {
        return;
      }

      setState(() {
        _products = products;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Loading products failed: '
        '$error\n$stackTrace',
      );

      if (!mounted ||
          requestRevision != _loadRequestRevision) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _friendlyError(error);
      });
    }
  }

  Future<void> _refreshProducts() {
    return _loadProducts(silent: true);
  }

  List<Product> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _products;
    }

    return _products.where((product) {
      final nameMatches =
          product.name.toLowerCase().contains(query);

      final skuMatches =
          product.sku?.toLowerCase().contains(query) ?? false;

      return nameMatches || skuMatches;
    }).toList();
  }

  // =========================================================
  // CREATE AND EDIT PRODUCTS
  // =========================================================

  Future<void> _openProductForm({
    Product? product,
  }) async {
    if (_isSaving) return;

    final formData = await showDialog<_ProductFormData>(
      context: context,
      builder: (_) => _ProductFormDialog(
        product: product,
      ),
    );

    if (formData == null || !mounted) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.productService.saveProduct(
        id: product?.id,
        name: formData.name,
        sku: formData.sku,
        unit: formData.unit,
        costPrice: formData.costPrice,
        sellingPrice: formData.sellingPrice,
        reorderLevel: formData.reorderLevel,
      );

      if (!mounted) return;

      // Announce the persisted change to subscribed screens.
      //
      // Products refreshes itself, Inventory refreshes its
      // product/stock list, and POS refreshes its catalogue.
      ShopFlowEvents.notifyDataChanged();

      _showMessage(
        product == null
            ? 'Product created successfully.'
            : 'Product updated successfully.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Saving product failed: '
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
          _isSaving = false;
        });
      }
    }
  }

  // =========================================================
  // DEACTIVATE PRODUCTS
  // =========================================================

  Future<void> _confirmDeactivation(Product product) async {
    if (_isSaving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Deactivate product?'),
          content: Text(
            '“${product.name}” will no longer appear in the '
            'active product catalogue. Existing transaction '
            'records will not be deliberately deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Deactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.productService.deactivateProduct(
        product.id,
      );

      if (!mounted) return;

      // Notify POS, Inventory, and other subscribed screens.
      ShopFlowEvents.notifyDataChanged();

      _showMessage('Product deactivated.');
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Deactivating product failed: '
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
          _isSaving = false;
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
    if (error is ProductValidationException ||
        error is ProductRepositoryException) {
      return error.toString();
    }

    return 'Something went wrong. '
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),

            const SizedBox(height: 14),

            _buildSearchField(),

            const SizedBox(height: 8),

            if (_isSaving ||
                (_isLoading && _products.isNotEmpty))
              const LinearProgressIndicator(
                minHeight: 2,
              ),

            if (_errorMessage != null &&
                _products.isNotEmpty)
              _buildInlineError(),

            Expanded(
              child: _buildProductList(),
            ),
          ],
        ),
      ),

      floatingActionButton: Transform.translate(
        offset: const Offset(0, -16),
        child: SizedBox(
          width: 56,
          height: 56,
          child: FloatingActionButton(
            heroTag: 'shopflow_add_product',
            tooltip: 'Add product',
            onPressed: _isSaving
                ? null
                : () => _openProductForm(),
            backgroundColor: AppColors.brand,
            foregroundColor: AppColors.textOnBrand,
            elevation: 4,
            shape: const CircleBorder(),
            child: const Icon(
              Icons.add_rounded,
              size: 28,
            ),
          ),
        ),
      ),

      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat,
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
                'Products',
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
                'Manage your product catalogue.',
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
          tooltip: 'Refresh products',
          visualDensity: VisualDensity.compact,
          onPressed: _isLoading || _isSaving
              ? null
              : _refreshProducts,
          icon: const Icon(
            Icons.refresh_rounded,
          ),
          color: AppColors.brand,
        ),
      ],
    );
  }

  // =========================================================
  // SEARCH FIELD
  // =========================================================

  /// Matches the Inventory search field:
  /// - fixed 46-pixel height;
  /// - matching surface and border;
  /// - matching search icon;
  /// - clear button shown only when a query exists.
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
            onPressed: _isLoading
                ? null
                : _refreshProducts,
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
  // PRODUCT LIST
  // =========================================================

  Widget _buildProductList() {
    if (_isLoading && _products.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 40,
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
                onPressed: _isLoading
                    ? null
                    : _refreshProducts,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final products = _filteredProducts;

    if (products.isEmpty) {
      final hasNoProducts = _products.isEmpty;

      return RefreshIndicator(
        onRefresh: _refreshProducts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 56),
            Icon(
              hasNoProducts
                  ? Icons.inventory_2_outlined
                  : Icons.search_off_rounded,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              hasNoProducts
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
              hasNoProducts
                  ? 'Tap + to create your first product.'
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

    return RefreshIndicator(
      onRefresh: _refreshProducts,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          top: 2,
          bottom: 100,
        ),
        itemCount: products.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          thickness: 1,
          color: AppColors.divider,
        ),
        itemBuilder: (context, index) {
          return _buildProductRow(products[index]);
        },
      ),
    );
  }

  // =========================================================
  // PRODUCT ROW
  // =========================================================

  /// Uses the same simple two-line visual hierarchy as Inventory.
  ///
  /// Line 1: Product name and selling price.
  /// Line 2: SKU/unit and product options.
  Widget _buildProductRow(Product product) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isSaving
            ? null
            : () => _openProductForm(product: product),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 13,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
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
                    'SLE ${formatSleMinor(product.sellingPrice)}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        if (product.sku != null &&
                            product.sku!.isNotEmpty)
                          'SKU: ${product.sku}',
                        'Unit: ${product.unit}',
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Product options',
                    enabled: !_isSaving,
                    padding: EdgeInsets.zero,
                    iconSize: 21,
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _openProductForm(product: product);
                        case 'deactivate':
                          _confirmDeactivation(product);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 10),
                            Text('Edit product'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'deactivate',
                        child: Row(
                          children: [
                            Icon(Icons.inventory_2_outlined),
                            SizedBox(width: 10),
                            Text('Deactivate'),
                          ],
                        ),
                      ),
                    ],
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
// PRODUCT FORM DATA
// ===========================================================

class _ProductFormData {
  const _ProductFormData({
    required this.name,
    required this.sku,
    required this.unit,
    required this.costPrice,
    required this.sellingPrice,
    required this.reorderLevel,
  });

  final String name;
  final String? sku;
  final String unit;

  /// Monetary values are stored as minor units.
  ///
  /// Example: SLE 12.50 is represented as 1250.
  final int costPrice;
  final int sellingPrice;

  final int reorderLevel;
}

// ===========================================================
// ADD / EDIT PRODUCT DIALOG
// ===========================================================

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({
    this.product,
  });

  final Product? product;

  @override
  State<_ProductFormDialog> createState() =>
      _ProductFormDialogState();
}

class _ProductFormDialogState
    extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _costController;
  late final TextEditingController _sellingController;
  late final TextEditingController _reorderController;

  String _unit = 'piece';

  static final RegExp _sleAmountPattern =
      RegExp(r'^(?:\d+(?:\.\d{0,2})?)?$');

  @override
  void initState() {
    super.initState();

    final product = widget.product;

    _nameController = TextEditingController(
      text: product?.name ?? '',
    );

    _skuController = TextEditingController(
      text: product?.sku ?? '',
    );

    _costController = TextEditingController(
      text: product == null
          ? ''
          : formatSleMinor(product.costPrice),
    );

    _sellingController = TextEditingController(
      text: product == null
          ? ''
          : formatSleMinor(product.sellingPrice),
    );

    _reorderController = TextEditingController(
      text: product?.reorderLevel.toString() ?? '0',
    );

    _unit = product?.unit ?? 'piece';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _costController.dispose();
    _sellingController.dispose();
    _reorderController.dispose();

    super.dispose();
  }

  List<TextInputFormatter> get _sleAmountFormatters => [
        TextInputFormatter.withFunction(
          (oldValue, newValue) {
            if (_sleAmountPattern.hasMatch(newValue.text)) {
              return newValue;
            }

            return oldValue;
          },
        ),
      ];

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final costPrice = parseSleToMinor(
      _costController.text,
    );

    final sellingPrice = parseSleToMinor(
      _sellingController.text,
    );

    final reorderLevel = int.tryParse(
      _reorderController.text.trim(),
    );

    if (costPrice == null ||
        sellingPrice == null ||
        reorderLevel == null) {
      return;
    }

    Navigator.of(context).pop(
      _ProductFormData(
        name: _nameController.text.trim(),
        sku: _skuController.text.trim(),
        unit: _unit,
        costPrice: costPrice,
        sellingPrice: sellingPrice,
        reorderLevel: reorderLevel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return AlertDialog(
      title: Text(
        isEditing ? 'Edit product' : 'Add product',
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Product name',
                    hintText: 'e.g. Palm Oil',
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter a product name.';
                    }

                    if (value.trim().length > 160) {
                      return 'Maximum 160 characters.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _skuController,
                  textCapitalization:
                      TextCapitalization.characters,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    labelText: 'SKU (optional)',
                    hintText: 'e.g. OIL-001',
                    counterText: '',
                  ),
                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                  ),
                  items: ProductService.units
                      .map(
                        (unit) => DropdownMenuItem<String>(
                          value: unit,
                          child: Text(unit),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _unit = value;
                    });
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _costController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _sleAmountFormatters,
                  decoration: const InputDecoration(
                    labelText: 'Cost price (SLE)',
                    hintText: 'e.g. 25.50',
                    helperText: 'Enter an amount in SLE.',
                  ),
                  validator: _requiredSleAmount,
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _sellingController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _sleAmountFormatters,
                  decoration: const InputDecoration(
                    labelText: 'Selling price (SLE)',
                    hintText: 'e.g. 35.00',
                    helperText: 'Enter an amount in SLE.',
                  ),
                  validator: _requiredSleAmount,
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _reorderController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Reorder level',
                    helperText:
                        'Alert threshold for low stock.',
                  ),
                  validator: _requiredNonNegativeInteger,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            isEditing ? 'Save changes' : 'Create product',
          ),
        ),
      ],
    );
  }

  String? _requiredSleAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    if (parseSleToMinor(value) == null) {
      return 'Enter a valid amount, e.g. 12.50.';
    }

    return null;
  }

  String? _requiredNonNegativeInteger(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    final number = int.tryParse(value.trim());

    if (number == null) {
      return 'Enter a whole number.';
    }

    if (number < 0) {
      return 'Value cannot be negative.';
    }

    return null;
  }
}