import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import 'shopflow_destination.dart';

class CommandCentreScreen extends StatelessWidget {
  const CommandCentreScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
    required this.isSigningOut,
  });

  final ValueChanged<ShopFlowDestination> onNavigate;
  final Future<void> Function() onSignOut;
  final bool isSigningOut;

  static const _items = <_CommandItemData>[
    _CommandItemData(
      label: 'Home',
      icon: Icons.home_rounded,
      destination: ShopFlowDestination.home,
    ),
    _CommandItemData(
      label: 'Point of Sale',
      icon: Icons.point_of_sale_rounded,
      destination: ShopFlowDestination.pos,
    ),
    _CommandItemData(
      label: 'Products',
      icon: Icons.inventory_2_outlined,
      destination: ShopFlowDestination.products,
    ),
    _CommandItemData(
      label: 'Inventory',
      icon: Icons.warehouse_outlined,
      destination: ShopFlowDestination.inventory,
    ),
    _CommandItemData(
      label: 'Categories',
      icon: Icons.category_outlined,
      destination: ShopFlowDestination.categories,
    ),
    _CommandItemData(
      label: 'Stock Movements',
      icon: Icons.swap_vert_rounded,
      destination: ShopFlowDestination.stockMovements,
    ),
    _CommandItemData(
      label: 'Sales History',
      icon: Icons.receipt_long_outlined,
      destination: ShopFlowDestination.salesHistory,
    ),
    _CommandItemData(
      label: 'Reports',
      icon: Icons.bar_chart_rounded,
      destination: ShopFlowDestination.reports,
    ),
    _CommandItemData(
      label: 'Settings',
      icon: Icons.settings_outlined,
      destination: ShopFlowDestination.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Keep the drawer wide enough for two columns,
    // but prevent it from dominating a desktop window.
    final double drawerWidth = math.min(
      screenWidth * 0.92,
      760.0,
    );

    return Drawer(
      width: drawerWidth,
      backgroundColor: AppColors.background,
      elevation: 16,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  24,
                  20,
                  24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 700,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Command Centre',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose where you want to work.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 24),

                        GridView.builder(
                          shrinkWrap: true,
                          physics:
                              const NeverScrollableScrollPhysics(),
                          itemCount: _items.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            mainAxisExtent: 124,
                          ),
                          itemBuilder: (context, index) {
                            final item = _items[index];

                            return _CommandCentreTile(
                              data: item,
                              onTap: isSigningOut
                                  ? null
                                  : () => _selectDestination(
                                        context,
                                        item.destination,
                                      ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Sign Out remains separate from regular destinations.
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  12,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 700,
                    ),
                    child: Column(
                      children: [
                        const Divider(
                          height: 1,
                          color: AppColors.divider,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: isSigningOut
                                ? null
                                : () => _handleSignOut(context),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            icon: const Icon(
                              Icons.logout_rounded,
                            ),
                            label: Text(
                              isSigningOut
                                  ? 'Signing out…'
                                  : 'Sign out',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.brand,
      padding: const EdgeInsets.fromLTRB(
        20,
        14,
        12,
        20,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.storefront_rounded,
            size: 27,
            color: AppColors.textOnBrand,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ShopFlow',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        color: AppColors.textOnBrand,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Command Centre',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: AppColors.textOnBrand.withValues(
                          alpha: 0.85,
                        ),
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close Command Centre',
            onPressed: () {
              Navigator.of(context).pop();
            },
            color: AppColors.textOnBrand,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  /// Closes the drawer, then navigates to the selected screen.
  void _selectDestination(
    BuildContext context,
    ShopFlowDestination destination,
  ) {
    Navigator.of(context).pop();
    onNavigate(destination);
  }

  /// Closes the drawer before requesting sign-out confirmation.
  Future<void> _handleSignOut(BuildContext context) async {
    Navigator.of(context).pop();
    await onSignOut();
  }
}

class _CommandItemData {
  const _CommandItemData({
    required this.label,
    required this.icon,
    required this.destination,
  });

  final String label;
  final IconData icon;
  final ShopFlowDestination destination;
}

class _CommandCentreTile extends StatelessWidget {
  const _CommandCentreTile({
    required this.data,
    required this.onTap,
  });

  final _CommandItemData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.border,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 12,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    data.icon,
                    size: 28,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  data.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}