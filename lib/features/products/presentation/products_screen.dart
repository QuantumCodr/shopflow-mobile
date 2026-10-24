import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/formatters/sle_money.dart';
import '../../../shared/theme/app_colors.dart';
import '../data/product_repository.dart';
import '../models/product.dart';
import '../services/product_service.dart';

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

  bool _isLoading = true;
  bool _isSaving = false;

  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final products =
          await widget.productService.getActiveProducts();

      if (!mounted) return;

      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Loading products failed: $error\n$stackTrace',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _friendlyError(error);
      });
    }
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            product == null
                ? 'Product created successfully.'
                : 'Product updated successfully.',
          ),
        ),
      );

      await _loadProducts();
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Saving product failed: $error\n$stackTrace',
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

  Future<void> _confirmDeactivation(Product product) async {
    if (_isSaving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Deactivate product?'),
          content: Text(
            '“${product.name}” will no longer appear in the active '
            'product catalogue. Existing transaction records will '
            'not be deliberately deleted.',
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
    });

    try {
      await widget.productService.deactivateProduct(product.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product deactivated.'),
        ),
      );

      await _loadProducts();
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Deactivating product failed: '
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
    if (error is ProductValidationException ||
        error is ProductRepositoryException) {
      return error.toString();
    }

    return 'Something went wrong. Please try again.';
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
                    'Products',
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
                    'Manage your product catalogue.',
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
                      hintText: 'Search by product name or SKU',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isSaving) const LinearProgressIndicator(),
                  Expanded(
                    child: _buildProductList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Transform.translate(
        offset: const Offset(0, -24),
        child: SizedBox(
          width: 56,
          height: 56,
          child: FloatingActionButton(
            heroTag: 'shopflow_add_product',
            tooltip: 'Add product',
            onPressed:
                _isSaving ? null : () => _openProductForm(),
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

  Widget _buildProductList() {
    if (_isLoading && _products.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _products.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          const Icon(
            Icons.cloud_off_outlined,
            size: 42,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    final products = _filteredProducts;

    if (products.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadProducts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 64),
            Icon(
              _searchQuery.isEmpty
                  ? Icons.inventory_2_outlined
                  : Icons.search_off_rounded,
              size: 44,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No products yet'
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
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Tap + to add your first product.'
                  : 'Try a different name or SKU.',
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
      onRefresh: _loadProducts,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          top: 4,
          bottom: 100,
        ),
        itemCount: products.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          color: AppColors.divider,
        ),
        itemBuilder: (context, index) {
          final product = products[index];

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
              [
                if (product.sku != null &&
                    product.sku!.isNotEmpty)
                  'SKU: ${product.sku}',
                'Unit: ${product.unit}',
                'Cost: SLE ${formatSleMinor(product.costPrice)}',
                'Reorder at: ${product.reorderLevel}',
              ].join('  ·  '),
              maxLines: 3,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
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
                PopupMenuButton<String>(
                  tooltip: 'Product options',
                  enabled: !_isSaving,
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openProductForm(product: product);
                    } else if (value == 'deactivate') {
                      _confirmDeactivation(product);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit product'),
                    ),
                    PopupMenuItem(
                      value: 'deactivate',
                      child: Text('Deactivate'),
                    ),
                  ],
                ),
              ],
            ),
            onTap: _isSaving
                ? null
                : () => _openProductForm(product: product),
          );
        },
      ),
    );
  }
}

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

  /// Prices are stored in minor units.
  /// Example: SLE 12.50 is represented as 1250.
  final int costPrice;
  final int sellingPrice;

  final int reorderLevel;
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({
    this.product,
  });

  final Product? product;

  @override
  State<_ProductFormDialog> createState() =>
      _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
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

    final costPrice =
        parseSleToMinor(_costController.text);

    final sellingPrice =
        parseSleToMinor(_sellingController.text);

    final reorderLevel =
        int.tryParse(_reorderController.text.trim());

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
      title: Text(isEditing ? 'Edit product' : 'Add product'),
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
                        (unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _unit = value;
                      });
                    }
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
          onPressed: () => Navigator.of(context).pop(),
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