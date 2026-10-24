import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../authentication/services/auth_service.dart';
import '../../home/presentation/home_screen.dart';
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

  /// Opens the Command Centre drawer over the current screen.
  void _openCommandCentre() {
    if (_isSigningOut) return;

    _scaffoldKey.currentState?.openDrawer();
  }

  /// Navigates to the exact destination selected in the drawer.
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
      // and returns to the appropriate authentication screen.
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

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature will be implemented next.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT:
    // This list follows the exact order of ShopFlowDestination.
    // The index of each enum value determines which screen opens.
    final screens = <Widget>[
      const HomeScreen(), // home: index 0

      const _ModulePlaceholder(
        title: 'Point of Sale',
        description: 'Your sales workspace will live here.',
        icon: Icons.point_of_sale_rounded,
      ), // pos: index 1

      const _ModulePlaceholder(
        title: 'Products',
        description: 'Your product catalogue will live here.',
        icon: Icons.inventory_2_outlined,
      ), // products: index 2

      const _ModulePlaceholder(
        title: 'Inventory',
        description: 'View and manage your stock levels here.',
        icon: Icons.warehouse_outlined,
      ), // inventory: index 3

      const _ModulePlaceholder(
        title: 'Categories',
        description: 'Organise your products into categories here.',
        icon: Icons.category_outlined,
      ), // categories: index 4

      const _ModulePlaceholder(
        title: 'Stock Movements',
        description:
            'Track stock additions, reductions, and adjustments here.',
        icon: Icons.swap_vert_rounded,
      ), // stockMovements: index 5

      const _ModulePlaceholder(
        title: 'Sales History',
        description: 'Review your previous transactions here.',
        icon: Icons.receipt_long_outlined,
      ), // salesHistory: index 6

      const _ModulePlaceholder(
        title: 'Reports',
        description:
            'Explore reports about your business performance here.',
        icon: Icons.bar_chart_rounded,
      ), // reports: index 7

      const _ModulePlaceholder(
        title: 'Settings',
        description: 'Manage ShopFlow preferences here.',
        icon: Icons.settings_outlined,
      ), // settings: index 8
    ];

    // Catch accidental enum/screen mismatches during development.
    assert(
      screens.length == ShopFlowDestination.values.length,
      'Every ShopFlowDestination must have a corresponding screen.',
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,

      // The Command Centre overlays the current screen.
      drawer: CommandCentreScreen(
        onNavigate: _navigateTo,
        onSignOut: _signOut,
        isSigningOut: _isSigningOut,
      ),

      drawerEnableOpenDragGesture: true,

      // Green AppBar with the ShopFlow brand centred.
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

      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _currentDestination.index,
          children: screens,
        ),
      ),

      floatingActionButton: _buildFloatingActionButton(),

      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat,
    );
  }

  /// Displays the action relevant to the current screen.
  Widget? _buildFloatingActionButton() {
    switch (_currentDestination) {
      case ShopFlowDestination.home:
        return _buildRoundActionButton(
          heroTag: 'shopflow_home_pos',
          tooltip: 'Open Point of Sale',
          icon: Icons.point_of_sale_rounded,
          size: 64,
          iconSize: 30,
          onPressed: () {
            _navigateTo(ShopFlowDestination.pos);
          },
        );

      case ShopFlowDestination.products:
        return _buildRoundActionButton(
          heroTag: 'shopflow_add_product',
          tooltip: 'Add product',
          icon: Icons.add_rounded,
          size: 56,
          iconSize: 28,
          onPressed: () {
            _showComingSoon('Product creation');
          },
        );

      default:
        return null;
    }
  }

  /// Builds a consistently styled circular floating action button.
  ///
  /// Transform.translate raises the button visually without
  /// introducing a bottom navigation bar or changing screen content.
  Widget _buildRoundActionButton({
    required String heroTag,
    required String tooltip,
    required IconData icon,
    required double size,
    required double iconSize,
    required VoidCallback onPressed,
  }) {
    return Transform.translate(
      offset: const Offset(0, -16),
      child: SizedBox(
        width: size,
        height: size,
        child: FloatingActionButton(
          heroTag: heroTag,
          tooltip: tooltip,
          onPressed: _isSigningOut ? null : onPressed,
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.textOnBrand,
          elevation: 4,
          highlightElevation: 6,
          shape: const CircleBorder(),
          child: Icon(
            icon,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}

/// Temporary presentation for modules that have not been implemented.
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