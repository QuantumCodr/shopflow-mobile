import 'package:flutter/material.dart';

import '../services/shop_service.dart';

class ShopSetupScreen extends StatefulWidget {
  const ShopSetupScreen({
    super.key,
    required this.shopService,
    required this.onShopCreated,
    required this.onSignOut,
  });

  final ShopService shopService;
  final Future<void> Function() onShopCreated;
  final Future<void> Function() onSignOut;

  @override
  State<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends State<ShopSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _shopNameController.dispose();
    super.dispose();
  }

  Future<void> _createShop() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.shopService.createShop(
        name: _shopNameController.text,
      );

      if (!mounted) return;

      await widget.onShopCreated();
    } on ShopValidationException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Shop creation failed: $error\n$stackTrace',
      );

      if (!mounted) return;

      setState(() {
        _errorMessage =
            'We could not create your shop. '
            'Please check your connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up Your Shop'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      size: 72,
                      color: Color(0xFF176B55),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome to ShopFlow',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Let’s get your business ready. '
                      'Start by telling us your shop name.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _shopNameController,
                      enabled: !_isSaving,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Shop name',
                        hintText: 'e.g. My Mini Mart',
                        prefixIcon: Icon(Icons.store_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your shop name.';
                        }

                        if (value.trim().length > 100) {
                          return 'Shop name must be 100 characters '
                              'or fewer.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.payments_outlined),
                        title: Text('Default currency'),
                        subtitle: Text(
                          'SLE — Sierra Leonean leone',
                        ),
                        trailing: Icon(Icons.lock_outline),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _createShop,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: Text(
                        _isSaving
                            ? 'Creating your shop...'
                            : 'Create My Shop',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}