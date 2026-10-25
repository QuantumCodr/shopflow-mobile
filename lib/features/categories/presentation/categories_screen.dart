import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/state/shopflow_events.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/shopflow_page_layout.dart';
import '../models/category.dart';
import '../services/category_service.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({
    super.key,
    this.categoryService,
  });

  final CategoryService? categoryService;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late final CategoryService _service;

  final TextEditingController _searchController =
      TextEditingController();

  List<ShopCategory> _categories = [];

  String _searchQuery = '';

  bool _isLoading = true;
  bool _isSaving = false;

  String? _errorMessage;

  int _loadRevision = 0;

  @override
  void initState() {
    super.initState();

    _service = widget.categoryService ?? CategoryService();

    ShopFlowEvents.dataRevision.addListener(_handleDataChanged);

    _loadCategories();
  }

  @override
  void dispose() {
    ShopFlowEvents.dataRevision.removeListener(_handleDataChanged);
    _searchController.dispose();

    super.dispose();
  }

  // =========================================================
  // DATA
  // =========================================================

  void _handleDataChanged() {
    if (!mounted) return;

    unawaited(_loadCategories(silent: true));
  }

  Future<void> _loadCategories({bool silent = false}) async {
    if (!mounted) return;

    final revision = ++_loadRevision;

    setState(() {
      if (!silent || _categories.isEmpty) {
        _isLoading = true;
      }

      _errorMessage = null;
    });

    try {
      final categories = await _service.getCategories();

      if (!mounted || revision != _loadRevision) return;

      setState(() {
        _categories = categories;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Categories loading failed: '
        '$error\n$stackTrace',
      );

      if (!mounted || revision != _loadRevision) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _friendlyError(error);
      });
    }
  }

  // =========================================================
  // SEARCH
  // =========================================================

  List<ShopCategory> get _filteredCategories {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return _categories;

    return _categories.where((category) {
      final matchesName =
          category.name.toLowerCase().contains(query);

      final matchesDescription =
          category.description?.toLowerCase().contains(query) ??
              false;

      return matchesName || matchesDescription;
    }).toList(growable: false);
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
    });
  }

  // =========================================================
  // CREATE OR EDIT CATEGORY
  // =========================================================

  Future<void> _openCategoryForm({
    ShopCategory? category,
  }) async {
    if (_isSaving) return;

    final formData = await showDialog<_CategoryFormData>(
      context: context,
      builder: (_) => _CategoryFormDialog(
        category: category,
      ),
    );

    if (formData == null || !mounted) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _service.saveCategory(
        id: category?.id,
        name: formData.name,
        description: formData.description,
      );

      if (!mounted) return;

      ShopFlowEvents.notifyDataChanged();

      _showMessage(
        category == null
            ? 'Category created successfully.'
            : 'Category updated successfully.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Saving category failed: '
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
  // ACTIVATE OR DEACTIVATE CATEGORY
  // =========================================================

  Future<void> _changeCategoryStatus(
    ShopCategory category,
  ) async {
    if (_isSaving) return;

    final shouldActivate = !category.isActive;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            shouldActivate
                ? 'Activate category?'
                : 'Deactivate category?',
          ),
          content: Text(
            shouldActivate
                ? '“${category.name}” will become active again.'
                : '“${category.name}” will be marked inactive. '
                    'Existing product assignments will be retained.',
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
              child: Text(
                shouldActivate ? 'Activate' : 'Deactivate',
              ),
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
      await _service.setCategoryActive(
        categoryId: category.id,
        isActive: shouldActivate,
      );

      if (!mounted) return;

      ShopFlowEvents.notifyDataChanged();

      _showMessage(
        shouldActivate
            ? 'Category activated.'
            : 'Category deactivated.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Updating category status failed: '
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
  // PRODUCT ASSIGNMENTS
  // =========================================================

  Future<void> _openProductAssignments(
    ShopCategory category,
  ) async {
    if (_isSaving) return;

    // Use a taller drawer on desktop while preserving the
    // original mobile proportions.
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    var productsFuture = _service.getProductsForCategory(
      categoryId: category.id,
    );

    // Keep these outside StatefulBuilder so rebuilds do not
    // reset in-progress changes.
    final busyIds = <String>{};

    Set<String>? selectedIds;

    String productSearch = '';
    String? lastActionMessage;
    bool lastActionFailed = false;

    final searchController = TextEditingController();

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> updateAssignment(
                CategoryProductOption product,
                bool shouldAssign,
              ) async {
                if (busyIds.contains(product.id)) return;

                if (!product.isActive && shouldAssign) return;

                final currentSelection = selectedIds;

                if (currentSelection == null) return;

                final wasAssigned =
                    currentSelection.contains(product.id);

                if (wasAssigned == shouldAssign) return;

                setSheetState(() {
                  lastActionMessage = null;
                  lastActionFailed = false;

                  if (shouldAssign) {
                    currentSelection.add(product.id);
                  } else {
                    currentSelection.remove(product.id);
                  }

                  busyIds.add(product.id);
                });

                try {
                  await _service.setProductAssigned(
                    categoryId: category.id,
                    productId: product.id,
                    isAssigned: shouldAssign,
                  );

                  if (!sheetContext.mounted) return;

                  setSheetState(() {
                    lastActionMessage = shouldAssign
                        ? '${product.name} added to this category.'
                        : '${product.name} removed from this category.';

                    lastActionFailed = false;
                  });

                  // Refresh other screens only after a successful write.
                  ShopFlowEvents.notifyDataChanged();
                } catch (error, stackTrace) {
                  debugPrint(
                    'SHOPFLOW: Product assignment failed: '
                    '$error\n$stackTrace',
                  );

                  if (!sheetContext.mounted) return;

                  // Roll back the optimistic selection on failure.
                  setSheetState(() {
                    if (wasAssigned) {
                      currentSelection.add(product.id);
                    } else {
                      currentSelection.remove(product.id);
                    }

                    lastActionMessage = _friendlyError(error);
                    lastActionFailed = true;
                  });
                } finally {
                  busyIds.remove(product.id);

                  if (sheetContext.mounted) {
                    setSheetState(() {});
                  }
                }
              }

              final savingCount = busyIds.length;

            return DraggableScrollableSheet(
              initialChildSize: isDesktop ? 0.80 : 0.82,
              minChildSize: isDesktop ? 0.65 : 0.55,
              maxChildSize: isDesktop ? 0.86 : 0.96,
              expand: false,
              builder: (context, scrollController)  {
                  return Container(
                    decoration: const BoxDecoration(
                      color: AppColors.background,
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
                              bottom: 12,
                            ),
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                        // Header.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            0,
                            12,
                            16,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(
                                    alpha: 0.09,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: AppColors.brand,
                                  size: 23,
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Organise products',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                            letterSpacing: -0.4,
                                          ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      category.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color:
                                                AppColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),

                        if (savingCount > 0)
                          const LinearProgressIndicator(
                            minHeight: 2,
                            color: AppColors.brand,
                          ),

                        // Search active products.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            0,
                            20,
                            12,
                          ),
                          child: SizedBox(
                            height: 46,
                            child: TextField(
                              controller: searchController,
                              onChanged: (value) {
                                setSheetState(() {
                                  productSearch = value;
                                });
                              },
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: 'Find a product...',
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 21,
                                ),
                                suffixIcon: productSearch.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear search',
                                        onPressed: () {
                                          searchController.clear();

                                          setSheetState(() {
                                            productSearch = '';
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
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.brand,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Selection summary.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            0,
                            20,
                            12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline,
                                      color: AppColors.brand,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${selectedIds?.length ?? 0} selected',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: AppColors.brand,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              if (savingCount > 0)
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 13,
                                      height: 13,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 7),
                                    Text('Saving changes'),
                                  ],
                                )
                              else
                                Text(
                                  'Changes save automatically',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                            ],
                          ),
                        ),

                        // Action feedback.
                        if (lastActionMessage != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              20,
                              0,
                              20,
                              10,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: lastActionFailed
                                    ? AppColors.error.withValues(
                                        alpha: 0.07,
                                      )
                                    : AppColors.success.withValues(
                                        alpha: 0.08,
                                      ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: lastActionFailed
                                      ? AppColors.error.withValues(
                                          alpha: 0.22,
                                        )
                                      : AppColors.success.withValues(
                                          alpha: 0.22,
                                        ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    lastActionFailed
                                        ? Icons.error_outline_rounded
                                        : Icons.check_circle_outline_rounded,
                                    size: 18,
                                    color: lastActionFailed
                                        ? AppColors.error
                                        : AppColors.success,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      lastActionMessage!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: lastActionFailed
                                                ? AppColors.error
                                                : AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const Divider(
                          height: 1,
                          color: AppColors.divider,
                        ),

                        // Product list.
                        Expanded(
                          child: FutureBuilder<
                              List<CategoryProductOption>>(
                            future: productsFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const _AssignmentLoadingState();
                              }

                              if (snapshot.hasError) {
                                return _AssignmentErrorState(
                                  message: _friendlyError(
                                    snapshot.error ?? 'Unknown error',
                                  ),
                                  onRetry: () {
                                    setSheetState(() {
                                      productsFuture =
                                          _service.getProductsForCategory(
                                        categoryId: category.id,
                                      );

                                      selectedIds = null;
                                    });
                                  },
                                );
                              }

                              final allProducts = snapshot.data ??
                                  const <CategoryProductOption>[];

                              final activeProducts = allProducts
                                  .where((product) => product.isActive)
                                  .toList(growable: false);

                              selectedIds ??= activeProducts
                                  .where((product) => product.isAssigned)
                                  .map((product) => product.id)
                                  .toSet();

                              final query =
                                  productSearch.trim().toLowerCase();

                              final visibleProducts =
                                  activeProducts.where((product) {
                                if (query.isEmpty) return true;

                                final matchesName = product.name
                                    .toLowerCase()
                                    .contains(query);

                                final matchesSku = product.sku
                                        ?.toLowerCase()
                                        .contains(query) ??
                                    false;

                                return matchesName || matchesSku;
                              }).toList(growable: false);

                              if (activeProducts.isEmpty) {
                                return const _AssignmentEmptyState(
                                  icon: Icons.inventory_2_outlined,
                                  title: 'Nothing to organise yet',
                                  message:
                                      'There are no active products '
                                      'available to assign. Add a product '
                                      'or reactivate one in Products.',
                                );
                              }

                              if (visibleProducts.isEmpty) {
                                return const _AssignmentEmptyState(
                                  icon: Icons.search_off_rounded,
                                  title: 'No matching products',
                                  message:
                                      'Try another name or SKU. '
                                      'Only active products are shown.',
                                );
                              }

                              return ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  20,
                                ),
                                itemCount: visibleProducts.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 7),
                                itemBuilder: (context, index) {
                                  final product =
                                      visibleProducts[index];

                                  final assigned = selectedIds!
                                      .contains(product.id);

                                  final busy =
                                      busyIds.contains(product.id);

                                  return _ProductAssignmentRow(
                                    product: product,
                                    isSelected: assigned,
                                    isSaving: busy,
                                    onTap: busy
                                        ? null
                                        : () {
                                            unawaited(
                                              updateAssignment(
                                                product,
                                                !assigned,
                                              ),
                                            );
                                          },
                                  );
                                },
                              );
                            },
                          ),
                        ),

                        // Footer.
                        Container(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            12,
                            20,
                            16,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border(
                              top: BorderSide(
                                color: AppColors.border.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                          ),
                          child: SafeArea(
                            top: false,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${selectedIds?.length ?? 0} products',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Assigned to this category',
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
                                const SizedBox(width: 16),
                                FilledButton.icon(
                                  onPressed: savingCount > 0
                                      ? null
                                      : () {
                                          Navigator.of(sheetContext).pop();
                                        },
                                  icon: const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Done'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.brand,
                                    foregroundColor:
                                        AppColors.textOnBrand,
                                    minimumSize: const Size(110, 44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
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
        },
      );
    } finally {
      searchController.dispose();
    }
  }

  // =========================================================
  // ERRORS AND MESSAGES
  // =========================================================

  String _friendlyError(Object error) {
    if (error is CategoryServiceException) {
      return error.toString();
    }

    return 'Something went wrong. '
        'Please check your connection and try again.';
  }

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
          backgroundColor: isError ? AppColors.error : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // =========================================================
  // MAIN SCREEN — MATCHES PRODUCTS SCREEN
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
                (_isLoading && _categories.isNotEmpty))
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.brand,
              ),
            if (_errorMessage != null &&
                _categories.isNotEmpty)
              _buildInlineError(),
            Expanded(
              child: _buildCategoryList(),
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
            heroTag: 'shopflow_add_category',
            tooltip: 'Add category',
            onPressed:
                _isSaving ? null : () => _openCategoryForm(),
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
                'Categories',
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
                'Organise products for easier management.',
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
          tooltip: 'Refresh categories',
          onPressed: _isLoading || _isSaving
              ? null
              : () => _loadCategories(),
          color: AppColors.brand,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  // =========================================================
  // SEARCH FIELD — MATCHES PRODUCTS SCREEN
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
        decoration: InputDecoration(
          hintText: 'Search categories',
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
                  onPressed: _clearSearch,
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
    return Container(
      margin: const EdgeInsets.only(top: 8),
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
              'Refresh failed. Showing the last loaded categories.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: _isLoading ? null : () => _loadCategories(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // CATEGORY LIST — PLAIN ROWS LIKE PRODUCTS
  // =========================================================

  Widget _buildCategoryList() {
    if (_isLoading && _categories.isEmpty) {
      return const _CategoryLoadingState();
    }

    if (_errorMessage != null && _categories.isEmpty) {
      return _CategoryEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load categories',
        message: _errorMessage!,
        actionLabel: 'Try again',
        onAction: () => _loadCategories(),
      );
    }

    final categories = _filteredCategories;

    if (categories.isEmpty) {
      final hasCategories = _categories.isNotEmpty;

      return _CategoryEmptyState(
        icon: hasCategories
            ? Icons.search_off_rounded
            : Icons.category_outlined,
        title: hasCategories
            ? 'No matching categories'
            : 'No categories yet',
        message: hasCategories
            ? 'Try another search term.'
            : 'Create your first category to organise related products.',
        actionLabel: hasCategories
            ? 'Clear search'
            : 'Create category',
        onAction: hasCategories
            ? _clearSearch
            : () => _openCategoryForm(),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCategories,
      color: AppColors.brand,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          top: 2,
          bottom: 100,
        ),
        itemCount: categories.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          thickness: 1,
          color: AppColors.divider,
        ),
        itemBuilder: (context, index) {
          return _buildCategoryRow(categories[index]);
        },
      ),
    );
  }

  // =========================================================
  // CATEGORY ROW
  // =========================================================

  Widget _buildCategoryRow(ShopCategory category) {
    final description =
        category.description?.trim().isNotEmpty == true
            ? category.description!.trim()
            : 'No description';

    final statusColor = category.isActive
        ? AppColors.success
        : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openProductAssignments(category),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 13,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // First line: category name and product count.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.15,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${category.productCount} '
                    '${category.productCount == 1 ? 'product' : 'products'}',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 5),

              // Second line: status, description and options.
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category.isActive ? 'Active' : 'Inactive',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      description,
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
                    tooltip: 'Category options',
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    enabled: !_isSaving,
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.textSecondary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _openCategoryForm(category: category);
                          break;
                        case 'products':
                          _openProductAssignments(category);
                          break;
                        case 'status':
                          _changeCategoryStatus(category);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit category'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'products',
                        child: ListTile(
                          leading: Icon(Icons.inventory_2_outlined),
                          title: Text('Manage products'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'status',
                        child: ListTile(
                          leading: Icon(
                            category.isActive
                                ? Icons.pause_circle_outline_rounded
                                : Icons.check_circle_outline_rounded,
                          ),
                          title: Text(
                            category.isActive
                                ? 'Deactivate'
                                : 'Activate',
                          ),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
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
// PRODUCT ASSIGNMENT ROW
// ===========================================================

class _ProductAssignmentRow extends StatelessWidget {
  const _ProductAssignmentRow({
    required this.product,
    required this.isSelected,
    required this.isSaving,
    required this.onTap,
  });

  final CategoryProductOption product;
  final bool isSelected;
  final bool isSaving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.brand.withValues(alpha: 0.055)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isSelected
                  ? AppColors.brand.withValues(alpha: 0.25)
                  : AppColors.border.withValues(alpha: 0.8),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.brand.withValues(alpha: 0.10)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSelected
                      ? Icons.check_rounded
                      : Icons.inventory_2_outlined,
                  size: 21,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 12),
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
                          .bodyMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    if (product.sku != null &&
                        product.sku!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'SKU ${product.sku}',
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
                    if (isSaving) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Saving change...',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: isSaving
                    ? const SizedBox(
                        key: ValueKey('saving'),
                        width: 23,
                        height: 23,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.brand,
                        ),
                      )
                    : Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        key: ValueKey(isSelected),
                        color: isSelected
                            ? AppColors.brand
                            : AppColors.textSecondary,
                        size: 24,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// ASSIGNMENT LOADING STATE — COMPACT FOR SHORT VIEWPORTS
// ===========================================================

class _AssignmentLoadingState extends StatelessWidget {
  const _AssignmentLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 30,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Preparing your products',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 7),
            Text(
              'Getting your active products and current assignments.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 18),
            const SizedBox(
              width: 145,
              child: LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// ASSIGNMENT ERROR STATE
// ===========================================================

class _AssignmentErrorState extends StatelessWidget {
  const _AssignmentErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                size: 28,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Products could not be loaded',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.textOnBrand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// ASSIGNMENT EMPTY STATE
// ===========================================================

class _AssignmentEmptyState extends StatelessWidget {
  const _AssignmentEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 30,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// CATEGORY LOADING STATE
// ===========================================================

class _CategoryLoadingState extends StatelessWidget {
  const _CategoryLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.brand,
      ),
    );
  }
}

// ===========================================================
// CATEGORY EMPTY STATE
// ===========================================================

class _CategoryEmptyState extends StatelessWidget {
  const _CategoryEmptyState({
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
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                icon,
                size: 32,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(actionLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.textOnBrand,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// CATEGORY FORM DATA
// ===========================================================

class _CategoryFormData {
  const _CategoryFormData({
    required this.name,
    required this.description,
  });

  final String name;
  final String? description;
}

// ===========================================================
// CATEGORY FORM DIALOG
// ===========================================================

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({
    this.category,
  });

  final ShopCategory? category;

  @override
  State<_CategoryFormDialog> createState() =>
      _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.category?.name ?? '',
    );

    _descriptionController = TextEditingController(
      text: widget.category?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final description = _descriptionController.text.trim();

    Navigator.of(context).pop(
      _CategoryFormData(
        name: _nameController.text.trim(),
        description: description.isEmpty ? null : description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isEditing ? Icons.edit_outlined : Icons.add_rounded,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Edit category' : 'New category',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  isEditing
                      ? 'Refine how products are organised.'
                      : 'Give related products a home.',
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
        ],
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
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: 'Category name',
                    hintText: 'e.g. Kitchen Essentials',
                    counterText: '',
                    prefixIcon: const Icon(
                      Icons.category_outlined,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.brand,
                        width: 1.4,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final name = value?.trim() ?? '';

                    if (name.isEmpty) {
                      return 'Enter a category name.';
                    }

                    if (name.length > 80) {
                      return 'Maximum 80 characters.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText:
                        'What kind of products belong here?',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.brand,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: AppColors.textOnBrand,
            padding: const EdgeInsets.symmetric(
              horizontal: 17,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          child: Text(
            isEditing ? 'Save changes' : 'Create category',
          ),
        ),
      ],
    );
  }
}