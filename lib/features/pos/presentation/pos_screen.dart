import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/formatters/sle_money.dart';
import '../../../shared/state/shopflow_events.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/shopflow_page_layout.dart';
import '../data/pos_repository.dart';
import '../models/pos_models.dart';
import '../services/pos_service.dart';

/// ShopFlow Point of Sale.
///
/// Responsibilities:
/// - Display active products and available stock.
/// - Search the catalogue by product name or SKU.
/// - Maintain a cart and calculate its displayed total.
/// - Present cart review using a draggable bottom sheet.
/// - Validate payment input before submitting a sale.
/// - Display the receipt returned by the service.
/// - Refresh when another feature announces a persisted change.
///
/// Prices and monetary calculations use minor units.
/// Stock and sale business rules remain in PosService
/// and PostgreSQL.
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

  final ScrollController _listScrollController =
      ScrollController();

  /// Cart entries are keyed by product ID.
  final Map<String, PosCartLine> _cart = {};

  List<PosCatalogItem> _catalog = [];

  bool _isLoading = true;
  bool _isProcessing = false;

  String? _errorMessage;
  String _searchQuery = '';

  /// Prevents an older network response from replacing newer data.
  int _loadRequestRevision = 0;

  @override
  void initState() {
    super.initState();

    _posService = widget.posService ?? PosService();

    ShopFlowEvents.dataRevision.addListener(
      _handleDataRevisionChanged,
    );

    _loadCatalog();
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
  // STATE MANAGEMENT AND CATALOGUE
  // =========================================================

  /// Refresh after another feature successfully persists a change.
  void _handleDataRevisionChanged() {
    if (!mounted) return;

    unawaited(_loadCatalog(silent: true));
  }

  Future<void> _loadCatalog({
    bool silent = false,
  }) async {
    if (!mounted) return;

    final requestRevision = ++_loadRequestRevision;

    setState(() {
      if (!silent || _catalog.isEmpty) {
        _isLoading = true;
      }

      _errorMessage = null;
    });

    try {
      final catalog = await _posService.loadCatalog();

      if (!mounted ||
          requestRevision != _loadRequestRevision) {
        return;
      }

      final reconciliation = _reconcileCart(catalog);

      setState(() {
        _catalog = catalog;

        _cart
          ..clear()
          ..addAll(reconciliation.cart);

        _isLoading = false;
        _errorMessage = null;
      });

      if (reconciliation.wasAdjusted) {
        _showMessage(
          'Your cart was updated because stock availability changed.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: POS catalogue loading failed: '
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

  Future<void> _refreshCatalog() {
    return _loadCatalog(silent: true);
  }

  // =========================================================
  // CART RECONCILIATION
  // =========================================================

  /// Reconcile the cart against the latest catalogue.
  ///
  /// - Remove products no longer active.
  /// - Remove products with zero recorded stock.
  /// - Reduce quantities that exceed availability.
  /// - Update product details and prices.
  ///
  /// PostgreSQL remains authoritative when a sale is submitted.
  _CartReconciliation _reconcileCart(
    List<PosCatalogItem> catalog,
  ) {
    final catalogById = <String, PosCatalogItem>{
      for (final item in catalog) item.product.id: item,
    };

    final reconciledCart = <String, PosCartLine>{};

    var wasAdjusted = false;

    for (final entry in _cart.entries) {
      final oldLine = entry.value;
      final latestItem = catalogById[entry.key];

      if (latestItem == null) {
        wasAdjusted = true;
        continue;
      }

      final availableQuantity = latestItem.availableQuantity;

      if (availableQuantity <= 0) {
        wasAdjusted = true;
        continue;
      }

      final safeQuantity =
          oldLine.quantity > availableQuantity
              ? availableQuantity
              : oldLine.quantity;

      if (safeQuantity != oldLine.quantity) {
        wasAdjusted = true;
      }

      if (oldLine.product.name != latestItem.product.name ||
          oldLine.product.sellingPrice !=
              latestItem.product.sellingPrice ||
          oldLine.product.unit != latestItem.product.unit) {
        wasAdjusted = true;
      }

      reconciledCart[entry.key] = PosCartLine(
        product: latestItem.product,
        quantity: safeQuantity,
      );
    }

    return _CartReconciliation(
      cart: reconciledCart,
      wasAdjusted: wasAdjusted,
    );
  }

  // =========================================================
  // SEARCH AND CART TOTALS
  // =========================================================

  List<PosCatalogItem> get _filteredCatalog {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _catalog;
    }

    return _catalog.where((item) {
      final product = item.product;

      final nameMatches =
          product.name.toLowerCase().contains(query);

      final skuMatches =
          product.sku?.toLowerCase().contains(query) ?? false;

      return nameMatches || skuMatches;
    }).toList();
  }

  int get _cartQuantity {
    return _cart.values.fold<int>(
      0,
      (sum, line) => sum + line.quantity,
    );
  }

  /// Money uses minor units.
  ///
  /// SLE 65.00 is represented as 6500.
  int get _cartTotal {
    return _cart.values.fold<int>(
      0,
      (sum, line) => sum + line.lineTotal,
    );
  }

  // =========================================================
  // ADD PRODUCTS TO CART
  // =========================================================

  void _addProduct(PosCatalogItem item) {
    if (_isProcessing) return;

    final product = item.product;
    final currentLine = _cart[product.id];
    final currentQuantity = currentLine?.quantity ?? 0;

    if (item.availableQuantity <= 0) {
      _showMessage(
        'This product has no recorded stock.',
      );
      return;
    }

    if (currentQuantity >= item.availableQuantity) {
      _showMessage(
        'You cannot add more than the available stock.',
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

  // =========================================================
  // CHANGE CART QUANTITIES
  // =========================================================

  void _changeQuantity(
    PosCartLine line,
    int difference,
  ) {
    if (_isProcessing) return;

    final productId = line.product.id;
    final currentQuantity =
        _cart[productId]?.quantity ?? 0;

    final nextQuantity = currentQuantity + difference;

    if (nextQuantity <= 0) {
      setState(() {
        _cart.remove(productId);
      });
      return;
    }

    PosCatalogItem? catalogItem;

    for (final item in _catalog) {
      if (item.product.id == productId) {
        catalogItem = item;
        break;
      }
    }

    if (catalogItem == null) {
      _showMessage(
        'This product is no longer available in the catalogue.',
      );

      unawaited(_refreshCatalog());
      return;
    }

    if (nextQuantity > catalogItem.availableQuantity) {
      _showMessage(
        'The requested quantity exceeds available stock.',
      );
      return;
    }

    setState(() {
      _cart[productId] = PosCartLine(
        product: catalogItem!.product,
        quantity: nextQuantity,
      );
    });
  }

  // =========================================================
  // CHECKOUT: OPEN THE CART
  // =========================================================

  /// Opens cart review as a draggable bottom sheet.
  ///
  /// The user must confirm the cart before the payment dialog opens.
  Future<void> _openCheckout() async {
    if (_cart.isEmpty || _isProcessing) return;

    final proceedToPayment = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _buildCartBottomSheet(sheetContext);
      },
    );

    // Closing or dismissing the sheet does not clear the cart.
    if (proceedToPayment != true ||
        !mounted ||
        _cart.isEmpty) {
      return;
    }

    await _openPaymentAndCompleteSale();
  }

  // =========================================================
  // CART BOTTOM SHEET
  // =========================================================

  Widget _buildCartBottomSheet(
    BuildContext sheetContext,
  ) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            final lines =
                _cart.values.toList(growable: false);

            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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

                  // Cart header.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      10,
                      12,
                      14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(
                              alpha: 0.09,
                            ),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            color: AppColors.brand,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Cart',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color:
                                          AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$_cartQuantity item(s) · '
                                'Review before payment',
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
                          tooltip: 'Close cart',
                          onPressed: () {
                            Navigator.of(sheetContext).pop(false);
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

                  // Cart items.
                  Expanded(
                    child: lines.isEmpty
                        ? ListView(
                            controller: scrollController,
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 48),
                              const Icon(
                                Icons.shopping_cart_outlined,
                                size: 46,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Your cart is empty',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'Add products from the catalogue '
                                'to get started.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color:
                                          AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            itemCount: lines.length,
                            separatorBuilder: (_, _) =>
                                const Divider(
                              height: 1,
                              color: AppColors.divider,
                            ),
                            itemBuilder: (context, index) {
                              final line = lines[index];

                              return _buildCartSheetLine(
                                line,
                                sheetSetState,
                              );
                            },
                          ),
                  ),

                  // Fixed total and continue button.
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      16,
                      20,
                      18,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(
                        top: BorderSide(
                          color: AppColors.divider,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Total due',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color:
                                            AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              Text(
                                'SLE ${formatSleMinor(_cartTotal)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              onPressed:
                                  _cart.isEmpty || _isProcessing
                                      ? null
                                      : () {
                                          Navigator.of(
                                            sheetContext,
                                          ).pop(true);
                                        },
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                              ),
                              label: const Text(
                                'Continue to payment',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                foregroundColor:
                                    AppColors.textOnBrand,
                              ),
                            ),
                          ),
                        ],
                      ),
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
  // CART ITEM ROW
  // =========================================================

  Widget _buildCartSheetLine(
    PosCartLine line,
    StateSetter sheetSetState,
  ) {
    final product = line.product;

    void changeQuantity(int difference) {
      final currentLine = _cart[product.id];

      if (currentLine == null) return;

      _changeQuantity(currentLine, difference);

      // Update the contents of the sheet as well.
      sheetSetState(() {});
    }

    void removeProduct() {
      if (_isProcessing) return;

      setState(() {
        _cart.remove(product.id);
      });

      sheetSetState(() {});
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'SLE ${formatSleMinor(product.sellingPrice)} '
                      'each · '
                      '${_unitLabel(product.unit, line.quantity)}',
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
                'SLE ${formatSleMinor(line.lineTotal)}',
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
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border.all(
                    color: AppColors.border,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 3,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _QuantityButton(
                      icon: Icons.remove_rounded,
                      onPressed: _isProcessing
                          ? null
                          : () => changeQuantity(-1),
                    ),
                    SizedBox(
                      width: 38,
                      child: Text(
                        '${line.quantity}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    _QuantityButton(
                      icon: Icons.add_rounded,
                      onPressed: _isProcessing ||
                              line.quantity >=
                                  (_catalog
                                          .where(
                                            (item) =>
                                                item.product.id ==
                                                product.id,
                                          )
                                          .firstOrNull
                                          ?.availableQuantity ??
                                      0)
                          ? null
                          : () => changeQuantity(1),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed:
                    _isProcessing ? null : removeProduct,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                ),
                label: const Text('Remove'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // CHECKOUT: PAYMENT AND SALE PROCESSING
  // =========================================================

  Future<void> _openPaymentAndCompleteSale() async {
    if (_cart.isEmpty || _isProcessing) return;

    // Capture a snapshot for this checkout operation.
    final lines = List<PosCartLine>.of(_cart.values);
    final total = _cartTotal;

    // Payment remains a traditional popup.
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
      _errorMessage = null;
    });

    try {
      final receipt = await _posService.completeSale(
        lines: lines,
        paymentAmount: paymentAmount,
      );

      // Notify other screens as soon as persistence succeeds.
      ShopFlowEvents.notifyDataChanged();

      if (!mounted) return;

      setState(() {
        _cart.clear();
      });

      // Keep the existing receipt popup.
      await _showReceipt(receipt);
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Checkout failed: '
        '$error\n$stackTrace',
      );

      if (!mounted) return;

      _showMessage(
        _friendlyError(error),
        isError: true,
      );

      // Refresh in case stock changed after the catalogue was loaded.
      unawaited(_refreshCatalog());
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // =========================================================
  // RECEIPT
  // =========================================================

  Future<void> _showReceipt(
    PosReceipt receipt,
  ) async {
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
                value:
                    'SLE ${formatSleMinor(receipt.total)}',
              ),

              _ReceiptRow(
                label: 'Received',
                value:
                    'SLE ${formatSleMinor(receipt.payment)}',
              ),

              _ReceiptRow(
                label: 'Change',
                value:
                    'SLE ${formatSleMinor(receipt.change)}',
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
    if (error is PosServiceException ||
        error is PosRepositoryException) {
      return error.toString();
    }

    return 'We could not complete the operation. '
        'Please check your connection and try again.';
  }

  String _unitLabel(
    String unit,
    int quantity,
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

            if (_isProcessing ||
                (_isLoading && _catalog.isNotEmpty))
              const LinearProgressIndicator(
                minHeight: 2,
              ),

            if (_errorMessage != null &&
                _catalog.isNotEmpty)
              _buildInlineError(),

            Expanded(
              child: _buildProductList(),
            ),

            _buildCartSummary(),
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
                'Point of Sale',
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
                'Select products and complete a sale.',
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
          tooltip: 'Refresh catalogue',
          visualDensity: VisualDensity.compact,
          onPressed: _isLoading || _isProcessing
              ? null
              : _refreshCatalog,
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

  /// Matches the Inventory and Products search fields.
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
                : _refreshCatalog,
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
    if (_isLoading && _catalog.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _catalog.isEmpty) {
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
                    : _refreshCatalog,
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

    final items = _filteredCatalog;

    if (items.isEmpty) {
      final hasNoProducts = _catalog.isEmpty;

      return RefreshIndicator(
        onRefresh: _refreshCatalog,
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
                  ? 'Create a product before making a sale.'
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

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
      ),
      child: Scrollbar(
        controller: _listScrollController,
        interactive: true,
        child: RefreshIndicator(
          onRefresh: _refreshCatalog,
          child: ListView.separated(
            controller: _listScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              top: 2,
              bottom: 16,
              right: 5,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.divider,
            ),
            itemBuilder: (context, index) {
              return _buildProductRow(items[index]);
            },
          ),
        ),
      ),
    );
  }

  // =========================================================
  // CLEAN POS PRODUCT ROW
  // =========================================================

  Widget _buildProductRow(
    PosCatalogItem item,
  ) {
    final product = item.product;

    final cartQuantity =
        _cart[product.id]?.quantity ?? 0;

    final isAvailable = item.availableQuantity > 0;

    final statusColor = isAvailable
        ? AppColors.success
        : AppColors.error;

    final statusLabel = isAvailable
        ? 'In stock'
        : 'Out of stock';

    final stockDescription =
        '${item.availableQuantity} '
        '${_unitLabel(product.unit, item.availableQuantity)}';

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '$statusLabel · $stockDescription',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildQuantityControls(
                  item,
                  cartQuantity,
                ),
              ],
            ),
            if (product.sku != null &&
                product.sku!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 13),
                child: Text(
                  'SKU: ${product.sku}',
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
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================
  // PRODUCT QUANTITY CONTROLS
  // =========================================================

  Widget _buildQuantityControls(
    PosCatalogItem item,
    int cartQuantity,
  ) {
    if (cartQuantity <= 0) {
      return SizedBox(
        height: 34,
        child: TextButton.icon(
          onPressed: _isProcessing ||
                  item.availableQuantity <= 0
              ? null
              : () => _addProduct(item),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brand,
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
            ),
            visualDensity: VisualDensity.compact,
          ),
          icon: const Icon(
            Icons.add_rounded,
            size: 18,
          ),
          label: const Text('Add'),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuantityButton(
          icon: Icons.remove_rounded,
          onPressed: _isProcessing
              ? null
              : () => _changeQuantity(
                    _cart[item.product.id]!,
                    -1,
                  ),
        ),
        SizedBox(
          width: 30,
          child: Text(
            '$cartQuantity',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        _QuantityButton(
          icon: Icons.add_rounded,
          onPressed: _isProcessing ||
                  cartQuantity >= item.availableQuantity
              ? null
              : () => _addProduct(item),
        ),
      ],
    );
  }

  // =========================================================
  // CART SUMMARY
  // =========================================================

  Widget _buildCartSummary() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        0,
        12,
        0,
        16,
      ),
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
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
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
                        letterSpacing: -0.3,
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
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: AppColors.textOnBrand,
            ),
            child: Text(
              _isProcessing
                  ? 'Processing…'
                  : 'Review cart',
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// CART RECONCILIATION RESULT
// ===========================================================

class _CartReconciliation {
  const _CartReconciliation({
    required this.cart,
    required this.wasAdjusted,
  });

  final Map<String, PosCartLine> cart;
  final bool wasAdjusted;
}

// ===========================================================
// QUANTITY BUTTON
// ===========================================================

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
        icon: Icon(
          icon,
          size: 18,
        ),
      ),
    );
  }
}

// ===========================================================
// RECEIPT ROW
// ===========================================================

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
    final style = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(
          fontWeight: emphasized
              ? FontWeight.w700
              : FontWeight.normal,
          color: AppColors.textPrimary,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style,
            ),
          ),
          Text(
            value,
            style: style,
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// CHECKOUT PAYMENT DIALOG
// ===========================================================

class _CheckoutDialog extends StatefulWidget {
  const _CheckoutDialog({
    required this.lines,
    required this.total,
  });

  final List<PosCartLine> lines;

  /// Total represented in minor currency units.
  final int total;

  @override
  State<_CheckoutDialog> createState() =>
      _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _paymentController =
      TextEditingController();

  static final RegExp _amountInputPattern =
      RegExp(r'^(?:\d+(?:\.\d{0,2})?)?$');

  /// Converts an entered SLE amount into minor units.
  int? get _paymentAmount {
    return parseSleToMinor(_paymentController.text);
  }

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
                    padding: const EdgeInsets.symmetric(
                      vertical: 5,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${line.product.name} × '
                            '${line.quantity}',
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
                  value:
                      'SLE ${formatSleMinor(widget.total)}',
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
                    final payment =
                        parseSleToMinor(value ?? '');

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

                if (received != null &&
                    received >= widget.total)
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
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }

            final amount = _paymentAmount;

            if (amount == null) return;

            // Return payment in minor currency units.
            Navigator.of(context).pop(amount);
          },
          child: const Text('Complete sale'),
        ),
      ],
    );
  }
}