import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../authentication/services/auth_service.dart';
import '../../home/presentation/home_screen.dart';
import '../../pos/presentation/pos_screen.dart';
import '../../products/presentation/products_screen.dart';
import 'command_centre_screen.dart';
import 'shopflow_destination.dart';

class ShopFlowShell extends StatefulWidget {
  const ShopFlowShell({super.key});

  @override
  State<ShopFlowShell> createState() => _ShopFlowShellState();
}

class _ShopFlowShellState extends State<ShopFlowShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();

  ShopFlowDestination _currentDestination =
      ShopFlowDestination.home;

  bool _isSigningOut = false;

  /// Opens the Command Centre over the current screen.
  void _openCommandCentre() {
    if (_isSigningOut) return;

    final scaffold = _scaffoldKey.currentState;

    if (scaffold == null || scaffold.isDrawerOpen) return;

    scaffold.openDrawer();
  }

  /// Navigates to the destination selected in the Command Centre.
  void _navigateTo(ShopFlowDestination destination) {
    if (!mounted || _isSigningOut) return;

    setState(() {
      _currentDestination = destination;
    });
  }

  /// Confirms and performs sign-out.
  Future<void> _signOut() async {
    if (_isSigningOut || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'You will need to sign in again to access your shop.',
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
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isSigningOut = true;
    });

    try {
      await AuthService().signOut();

      // AuthGate observes the Supabase authentication change
      // and returns the user to the appropriate screen.
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Sign out failed: $error\n$stackTrace',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sign out failed. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT:
    // This list must follow ShopFlowDestination exactly.
    //
    // The Command Centre is a drawer, so it is not included here.
    final screens = <Widget>[
      const HomeScreen(),       // 0: home
      const PosScreen(),        // 1: pos
      ProductsScreen(),         // 2: products

      const _ModulePlaceholder(
        title: 'Inventory',
        description: 'View and manage your stock levels here.',
        icon: Icons.warehouse_outlined,
      ),                         // 3: inventory

      const _ModulePlaceholder(
        title: 'Categories',
        description: 'Organise your products into categories here.',
        icon: Icons.category_outlined,
      ),                         // 4: categories

      const _ModulePlaceholder(
        title: 'Stock Movements',
        description:
            'Track stock additions, reductions, and adjustments here.',
        icon: Icons.swap_vert_rounded,
      ),                         // 5: stockMovements

      const _ModulePlaceholder(
        title: 'Sales History',
        description: 'Review your previous transactions here.',
        icon: Icons.receipt_long_outlined,
      ),                         // 6: salesHistory

      const _ModulePlaceholder(
        title: 'Reports',
        description:
            'Explore reports about your business performance here.',
        icon: Icons.bar_chart_rounded,
      ),                         // 7: reports

      const _ModulePlaceholder(
        title: 'Settings',
        description: 'Manage ShopFlow preferences here.',
        icon: Icons.settings_outlined,
      ),                         // 8: settings
    ];

    // Detect accidental differences between the enum and screen list.
    assert(
      screens.length == ShopFlowDestination.values.length,
      'Every ShopFlowDestination must have a corresponding screen.',
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,

      // The Command Centre overlays the currently selected screen.
      drawer: CommandCentreScreen(
        onNavigate: _navigateTo,
        onSignOut: _signOut,
        isSigningOut: _isSigningOut,
      ),

      drawerEnableOpenDragGesture: true,

      // Shared green AppBar with a centred ShopFlow brand.
      appBar: AppBar(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.textOnBrand,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,

        leading: IconButton(
          tooltip: 'Open Command Centre',
          onPressed: _isSigningOut ? null : _openCommandCentre,
          icon: const Icon(Icons.menu_rounded),
        ),

        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.storefront_rounded,
              size: 23,
            ),
            const SizedBox(width: 8),
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
          ],
        ),
      ),

      // Keeps the state of each destination while navigating.
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _currentDestination.index,
          children: screens,
        ),
      ),

      // Home has the POS shortcut. Products manages its own
      // Add Product button, so the shell must not duplicate it.
      floatingActionButton: _buildFloatingActionButton(),

      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat,
    );
  }

  /// Builds the primary floating action for the current screen.
  Widget? _buildFloatingActionButton() {
    if (_currentDestination != ShopFlowDestination.home) {
      return null;
    }

    return Transform.translate(
      offset: const Offset(0, -24),
      child: SizedBox(
        width: 64,
        height: 64,
        child: FloatingActionButton(
          heroTag: 'shopflow_home_pos',
          tooltip: 'Open Point of Sale',
          onPressed: _isSigningOut
              ? null
              : () => _navigateTo(ShopFlowDestination.pos),
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.textOnBrand,
          elevation: 4,
          highlightElevation: 6,
          shape: const CircleBorder(),
          child: const Icon(
            Icons.point_of_sale_rounded,
            size: 30,
          ),
        ),
      ),
    );
  }
}

/// Temporary presentation for modules that haven't been implemented.
class _ModulePlaceholder extends StatelessWidget {
  const _ModulePlaceholder({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 420,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 52,
                color: AppColors.brand,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}