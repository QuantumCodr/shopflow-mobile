import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
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
    // Prevent duplicate submissions.
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.shopService.createShop(
        name: _shopNameController.text.trim(),
      );

      if (!mounted) return;

      // Recheck shop ownership and continue into ShopFlow.
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
    if (_isSaving) return;

    await widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible =
        MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Reduce spacing when screen height is limited.
            final compact =
                constraints.maxHeight < 620 || keyboardVisible;

            final veryCompact = constraints.maxHeight < 430;

            final horizontalPadding =
                constraints.maxWidth < 360 ? 20.0 : 24.0;

            final verticalPadding = veryCompact
                ? 4.0
                : compact
                    ? 12.0
                    : 24.0;

            return Column(
              children: [
                _buildHeader(
                  horizontalPadding: horizontalPadding,
                ),

                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 420,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              // ShopFlow brand icon.
                              Icon(
                                Icons.storefront_rounded,
                                size: veryCompact
                                    ? 44
                                    : compact
                                        ? 52
                                        : 64,
                                color: AppColors.brand,
                              ),

                              SizedBox(
                                height: compact ? 16 : 24,
                              ),

                              // Welcome heading.
                              Text(
                                'Welcome to ShopFlow',
                                textAlign: TextAlign.center,
                                style: (compact
                                        ? Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                        : Theme.of(context)
                                            .textTheme
                                            .headlineMedium)
                                    ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),

                              // Welcome message.
                              if (!veryCompact && !keyboardVisible) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Let’s get your business ready. '
                                  'Start by telling us your shop name.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color:
                                            AppColors.textSecondary,
                                      ),
                                ),
                              ],

                              SizedBox(
                                height: compact ? 20 : 28,
                              ),

                              // Shop name input.
                              TextFormField(
                                controller: _shopNameController,
                                enabled: !_isSaving,
                                maxLength: 100,
                                textCapitalization:
                                    TextCapitalization.words,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _createShop(),
                                onChanged: (_) {
                                  if (_errorMessage != null) {
                                    setState(() {
                                      _errorMessage = null;
                                    });
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: 'Shop name',
                                  hintText: 'e.g. Family Mini Mart',
                                  counterText: '',
                                  contentPadding:
                                      EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: compact ? 14 : 18,
                                  ),
                                ),
                                validator: (value) {
                                  final name = value?.trim() ?? '';

                                  if (name.isEmpty) {
                                    return 'Please enter your shop name.';
                                  }

                                  if (name.length > 100) {
                                    return 'Shop name must be 100 '
                                        'characters or fewer.';
                                  }

                                  return null;
                                },
                              ),

                              SizedBox(
                                height: compact ? 16 : 20,
                              ),

                              // Fixed default currency.
                              _buildCurrencyInfo(
                                compact: compact,
                              ),

                              // Creation errors appear close to the action.
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 16),
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.error,
                                        ),
                                  ),
                                ),
                              ],

                              SizedBox(
                                height: compact ? 20 : 28,
                              ),

                              // Primary action.
                              SizedBox(
                                height: 48,
                                child: FilledButton(
                                  onPressed:
                                      _isSaving ? null : _createShop,
                                  child: _isSaving
                                      ? const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 18,
                                              height: 18,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                  AppColors.textOnBrand,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Text('Creating shop…'),
                                          ],
                                        )
                                      : const Text('Create shop'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Minimal header consistent with the other ShopFlow screens.
  Widget _buildHeader({
    required double horizontalPadding,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        8,
        horizontalPadding,
        8,
      ),
      child: Row(
        children: [
          Text(
            'ShopFlow',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _isSaving ? null : _signOut,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  /// Displays the default currency without adding another Card.
  Widget _buildCurrencyInfo({
    required bool compact,
  }) {
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        );

    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        );

    if (compact) {
      return Row(
        children: [
          Text(
            'Currency',
            style: labelStyle,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'SLE · Sierra Leonean leone',
              textAlign: TextAlign.end,
              style: valueStyle,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Currency',
          style: labelStyle,
        ),
        const SizedBox(height: 4),
        Text(
          'SLE · Sierra Leonean leone',
          style: valueStyle,
        ),
      ],
    );
  }
}