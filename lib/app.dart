import 'package:flutter/material.dart';

import 'features/authentication/presentation/auth_gate.dart';
import 'features/authentication/services/auth_service.dart';

const Color shopFlowGreen = Color(0xFF176B55);
const Color shopFlowBackground = Color(0xFFF6F8F7);

class ShopFlowApp extends StatelessWidget {
  const ShopFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShopFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: shopFlowGreen,
        ),
        scaffoldBackgroundColor: shopFlowBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: shopFlowBackground,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: AuthGate(
        authService: AuthService(),
        authenticatedBuilder: (_) => const ShopFlowShell(),
      ),
    );
  }
}

class ShopFlowShell extends StatefulWidget {
  const ShopFlowShell({super.key});

  @override
  State<ShopFlowShell> createState() => _ShopFlowShellState();
}

class _ShopFlowShellState extends State<ShopFlowShell> {
  int _selectedIndex = 0;

  final List<String> _titles = const [
    'ShopFlow',
    'Point of Sale',
    'Products',
  ];

  void _openCommandCentre() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ShopFlowCommandCentre(),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      ShopFlowHomeScreen(
        onStartSelling: () {
          setState(() => _selectedIndex = 1);
        },
        onAddProduct: () {
          setState(() => _selectedIndex = 2);
        },
      ),
      const PlaceholderScreen(
        title: 'Point of Sale',
        description: 'Your sales workspace will live here.',
        icon: Icons.point_of_sale_rounded,
      ),
      const PlaceholderScreen(
        title: 'Products',
        description: 'Manage your product catalogue here.',
        icon: Icons.inventory_2_outlined,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Open Command Centre',
          onPressed: _openCommandCentre,
          icon: const Icon(Icons.menu_rounded),
        ),
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              _showMessage(
                'Notifications are not available yet.',
              );
            },
            icon: const Icon(
              Icons.notifications_none_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale_rounded),
            label: 'POS',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Products',
          ),
        ],
      ),
    );
  }
}

class ShopFlowHomeScreen extends StatelessWidget {
  const ShopFlowHomeScreen({
    super.key,
    required this.onStartSelling,
    required this.onAddProduct,
  });

  final VoidCallback onStartSelling;
  final VoidCallback onAddProduct;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: shopFlowGreen,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                  SizedBox(height: 18),
                  Text(
                    'Welcome to ShopFlow',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your business, one place.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: QuickActionCard(
                    icon: Icons.add_box_outlined,
                    label: 'Add Product',
                    onTap: onAddProduct,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: QuickActionCard(
                    icon: Icons.point_of_sale_rounded,
                    label: 'Start Selling',
                    onTap: onStartSelling,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              'Business Overview',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFE7ECE9),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.insights_rounded,
                    color: shopFlowGreen,
                    size: 30,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Your business overview starts here',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'As you add products and record sales, '
                    'ShopFlow will display useful business '
                    'information here.',
                    style: TextStyle(
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: shopFlowGreen,
                size: 28,
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShopFlowCommandCentre extends StatelessWidget {
  const ShopFlowCommandCentre({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Command Centre',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Your business, one place.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 28),
          const CommandSection(
            title: 'Stock & Inventory',
            items: [
              CommandItem(
                label: 'Inventory',
                icon: Icons.inventory_2_outlined,
              ),
              CommandItem(
                label: 'Low Stock',
                icon: Icons.warning_amber_rounded,
              ),
              CommandItem(
                label: 'Stock Adjustments',
                icon: Icons.tune_rounded,
              ),
              CommandItem(
                label: 'Stock Movement',
                icon: Icons.swap_vert_rounded,
              ),
            ],
          ),
          const SizedBox(height: 28),
          const CommandSection(
            title: 'Business Insights',
            items: [
              CommandItem(
                label: 'Reports',
                icon: Icons.bar_chart_rounded,
              ),
              CommandItem(
                label: 'Sales History',
                icon: Icons.receipt_long_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            trailing: const Icon(
              Icons.chevron_right_rounded,
            ),
            onTap: () {
              _showMessage(context, 'Settings');
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.help_outline_rounded,
            ),
            title: const Text('Help & Support'),
            trailing: const Icon(
              Icons.chevron_right_rounded,
            ),
            onTap: () {
              _showMessage(context, 'Help & Support');
            },
          ),
          const SizedBox(height: 12),
          const Divider(),
          ListTile(
            leading: const Icon(
              Icons.logout_rounded,
              color: Colors.red,
            ),
            title: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () => _confirmSignOut(context),
          ),
        ],
      ),
    );
  }

  static void _showMessage(
    BuildContext context,
    String feature,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature will be implemented later.'),
      ),
    );
  }

  static Future<void> _confirmSignOut(
    BuildContext context,
  ) async {
    final shouldSignOut = await showDialog<bool>(
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
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true || !context.mounted) {
      return;
    }

    try {
      await AuthService().signOut();
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sign out failed. Please try again.',
          ),
        ),
      );
    }
  }
}

class CommandSection extends StatelessWidget {
  const CommandSection({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<CommandItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: shopFlowGreen,
            fontSize: 12,
            letterSpacing: 1.1,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (context, index) => items[index],
        ),
      ],
    );
  }
}

class CommandItem extends StatelessWidget {
  const CommandItem({
    super.key,
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$label will be implemented next.',
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: shopFlowGreen,
                size: 25,
              ),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
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
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 58,
              color: shopFlowGreen,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}