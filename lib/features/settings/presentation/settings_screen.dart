import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/shopflow_page_layout.dart';
import '../models/settings_models.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.settingsService,
    required this.onSignOut,
    required this.isSigningOut,
  });

  final SettingsService? settingsService;
  final Future<void> Function() onSignOut;
  final bool isSigningOut;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsService _service;

  SettingsSnapshot? _snapshot;

  bool _isLoading = true;
  bool _isSavingName = false;
  bool _isSendingRecovery = false;

  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();

    _service = widget.settingsService ?? SettingsService();

    unawaited(_loadSettings());
  }

  // =========================================================
  // DATA
  // =========================================================

  Future<void> _loadSettings() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final snapshot = await _service.loadSettings();

      if (!mounted) return;

      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Settings loading failed: $error\n$stackTrace',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error is SettingsServiceException
            ? error.message
            : 'Could not load settings. Please try again.';
      });
    }
  }

  // =========================================================
  // SHOP NAME
  // =========================================================

  Future<void> _editShopName() async {
    final snapshot = _snapshot;

    if (snapshot == null || _isSavingName) return;

    final controller = TextEditingController(
      text: snapshot.shop.name,
    );

    String? newName;

    try {
      newName = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Edit shop name'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Shop name',
                hintText: 'Enter your shop name',
              ),
              onSubmitted: (value) {
                Navigator.of(dialogContext).pop(value);
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(
                    controller.text,
                  );
                },
                child: const Text('Save changes'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }

    if (!mounted || newName == null) return;

    final normalizedName = newName.trim();

    if (normalizedName.isEmpty) {
      _showMessage(
        'Enter a shop name.',
        isError: true,
      );
      return;
    }

    if (normalizedName == snapshot.shop.name) return;

    setState(() {
      _isSavingName = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final updatedShop = await _service.updateShopName(
        normalizedName,
      );

      if (!mounted) return;

      setState(() {
        _snapshot = SettingsSnapshot(
          accountEmail: snapshot.accountEmail,
          shop: updatedShop,
        );

        _isSavingName = false;
        _successMessage = 'Shop name updated successfully.';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isSavingName = false;
        _errorMessage = error is SettingsServiceException
            ? error.message
            : 'Could not update the shop name.';
      });
    }
  }

  // =========================================================
  // CHANGE PASSWORD
  // =========================================================

  Future<void> _changePassword() async {
    final result = await showDialog<_PasswordChangeInput>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );

    if (!mounted || result == null) return;

    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _service.changePassword(
        currentPassword: result.currentPassword,
        newPassword: result.newPassword,
      );

      if (!mounted) return;

      setState(() {
        _successMessage =
            'Your password has been changed successfully.';
      });
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Password change failed: $error\n$stackTrace',
      );

      if (!mounted) return;

      setState(() {
        _errorMessage = error is SettingsServiceException
            ? error.message
            : 'Could not change your password. '
                'Check your current password and try again.';
      });
    }
  }

  // =========================================================
  // PASSWORD RECOVERY
  // =========================================================

  Future<void> _sendPasswordRecoveryEmail() async {
    if (_isSendingRecovery) return;

    setState(() {
      _isSendingRecovery = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _service.sendPasswordRecoveryEmail();

      if (!mounted) return;

      setState(() {
        _isSendingRecovery = false;
        _successMessage =
            'Password recovery requested. Check your inbox and '
            'spam folder for further instructions.';
      });
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Password recovery request failed: '
        '$error\n$stackTrace',
      );

      if (!mounted) return;

      setState(() {
        _isSendingRecovery = false;
        _errorMessage = error is SettingsServiceException
            ? error.message
            : 'Could not request password recovery. Please try again.';
      });
    }
  }

  // =========================================================
  // COPY SHOP REFERENCE
  // =========================================================

  Future<void> _copyShopReference(String shopId) async {
    try {
      await Clipboard.setData(
        ClipboardData(text: shopId),
      );

      if (!mounted) return;

      _showMessage('Shop reference copied.');
    } catch (error) {
      debugPrint(
        'SHOPFLOW: Copy shop reference failed: $error',
      );

      if (!mounted) return;

      _showMessage(
        'Could not copy the shop reference.',
        isError: true,
      );
    }
  }

  String _shortId(String id) {
    if (id.length <= 12) return id;

    return '${id.substring(0, 8)}…${id.substring(id.length - 4)}';
  }

  // =========================================================
  // MESSAGES
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
          backgroundColor: isError
              ? AppColors.error
              : AppColors.brand,
        ),
      );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
        ),
        child: ShopFlowPageLayout(
          child: RefreshIndicator(
            onRefresh: _loadSettings,
            color: AppColors.brand,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                0,
                24,
                0,
                100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    _buildMessage(
                      _errorMessage!,
                      isError: true,
                    ),
                  ],

                  if (_successMessage != null) ...[
                    const SizedBox(height: 16),
                    _buildMessage(
                      _successMessage!,
                      isError: false,
                    ),
                  ],

                  if (_isLoading && snapshot == null) ...[
                    const SizedBox(height: 36),
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text('Loading your settings...'),
                    ),
                  ] else if (snapshot != null) ...[
                    const SizedBox(height: 28),

                    _buildSectionHeading(
                      'SHOP PROFILE',
                      subtitle: 'Manage your shop information',
                    ),

                    const SizedBox(height: 12),

                    _buildShopProfile(snapshot),

                    const SizedBox(height: 28),

                    _buildSectionHeading(
                      'ACCOUNT & SECURITY',
                      subtitle:
                          'Your sign-in identity and account security',
                    ),

                    const SizedBox(height: 12),

                    _buildAccountSecurity(snapshot),

                    const SizedBox(height: 28),

                    _buildSectionHeading(
                      'BUSINESS PREFERENCES',
                      subtitle:
                          'Regional settings used by ShopFlow',
                    ),

                    const SizedBox(height: 12),

                    _buildBusinessPreferences(snapshot),

                    const SizedBox(height: 28),

                    _buildSectionHeading(
                      'ABOUT',
                      subtitle: 'Your business management workspace',
                    ),

                    const SizedBox(height: 12),

                    _buildAbout(),

                    const SizedBox(height: 28),

                    _buildSignOutButton(),
                  ],

                  if (_isLoading && snapshot != null) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(
                      minHeight: 2,
                      color: AppColors.brand,
                    ),
                  ],

                  if (!_isLoading &&
                      snapshot == null &&
                      _errorMessage != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _loadSettings,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
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
                'Settings',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                'Manage your shop, account, and preferences.',
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
        IconButton(
          tooltip: 'Refresh settings',
          onPressed: _isLoading ? null : _loadSettings,
          icon: const Icon(Icons.refresh_rounded),
          color: AppColors.brand,
        ),
      ],
    );
  }

  // =========================================================
  // SECTION HEADING
  // =========================================================

  Widget _buildSectionHeading(
    String title, {
    String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ],
    );
  }

  // =========================================================
  // SHOP PROFILE
  // =========================================================

  Widget _buildShopProfile(SettingsSnapshot snapshot) {
    final shop = snapshot.shop;

    return _SettingsPanel(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.brand,
                  size: 31,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      shop.isActive ? 'Active shop' : 'Inactive shop',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: shop.isActive
                                ? AppColors.success
                                : AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Edit shop name',
                onPressed: _isSavingName ? null : _editShopName,
                icon: _isSavingName
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.edit_outlined),
                color: AppColors.brand,
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Divider(
            height: 1,
            color: AppColors.divider,
          ),

          const SizedBox(height: 14),

          _SettingsDetailRow(
            icon: Icons.payments_outlined,
            label: 'Shop currency',
            value: shop.currencyCode,
          ),

          const SizedBox(height: 14),

          _SettingsDetailRow(
            icon: Icons.verified_user_outlined,
            label: 'Account access',
            value: 'Owner account',
          ),

          const SizedBox(height: 14),

          _SettingsDetailRow(
            icon: Icons.fingerprint_rounded,
            label: 'Shop reference',
            value: _shortId(shop.id),
            onCopy: () => _copyShopReference(shop.id),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ACCOUNT & SECURITY
  // =========================================================

  Widget _buildAccountSecurity(SettingsSnapshot snapshot) {
    return _SettingsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingsDetailRow(
            icon: Icons.mail_outline_rounded,
            label: 'Signed-in email',
            value: snapshot.accountEmail.isEmpty
                ? 'Email unavailable'
                : snapshot.accountEmail,
          ),

          const SizedBox(height: 16),

          const Divider(
            height: 1,
            color: AppColors.divider,
          ),

          const SizedBox(height: 16),

          // CHANGE PASSWORD
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Change password',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Update your password using your current credentials.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _changePassword,
                      icon: const Icon(Icons.lock_reset_rounded),
                      label: const Text('Change password'),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Divider(
            height: 1,
            color: AppColors.divider,
          ),

          const SizedBox(height: 16),

          // PASSWORD RECOVERY
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Password recovery',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Request a reset email if you have forgotten '
                      'your password.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isSendingRecovery
                          ? null
                          : _sendPasswordRecoveryEmail,
                      icon: _isSendingRecovery
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.email_outlined,
                            ),
                      label: Text(
                        _isSendingRecovery
                            ? 'Sending request...'
                            : 'Send password reset email',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // BUSINESS PREFERENCES
  // =========================================================

  Widget _buildBusinessPreferences(SettingsSnapshot snapshot) {
    return _SettingsPanel(
      child: Column(
        children: [
          _SettingsDetailRow(
            icon: Icons.schedule_rounded,
            label: 'Business timezone',
            value: 'Sierra Leone (UTC+00:00)',
          ),

          const SizedBox(height: 16),

          const Divider(
            height: 1,
            color: AppColors.divider,
          ),

          const SizedBox(height: 16),

          _SettingsDetailRow(
            icon: Icons.payments_outlined,
            label: 'Reporting currency',
            value: snapshot.shop.currencyCode,
          ),

          const SizedBox(height: 14),

          const _SettingsNotice(
            message:
                'ShopFlow uses Sierra Leone business time for daily '
                'sales, reporting periods, and stock movement dates. '
                'These preferences are informational and are not '
                'currently editable.',
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ABOUT
  // =========================================================

  Widget _buildAbout() {
    return _SettingsPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              size: 28,
              color: AppColors.textOnBrand,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ShopFlow',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your business, one place.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Business management for products, inventory, '
                  'sales, and reporting.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SIGN OUT
  // =========================================================

  Widget _buildSignOutButton() {
    return OutlinedButton.icon(
      onPressed: widget.isSigningOut ? null : widget.onSignOut,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: BorderSide(
          color: AppColors.error.withValues(alpha: 0.4),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: widget.isSigningOut
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.logout_rounded),
      label: Text(
        widget.isSigningOut
            ? 'Signing out...'
            : 'Sign out of ShopFlow',
      ),
    );
  }

  // =========================================================
  // MESSAGE PANEL
  // =========================================================

  Widget _buildMessage(
    String message, {
    required bool isError,
  }) {
    final accent = isError
        ? AppColors.error
        : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Dismiss message',
            constraints: const BoxConstraints(
              minWidth: 30,
              minHeight: 30,
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            onPressed: () {
              setState(() {
                if (isError) {
                  _errorMessage = null;
                } else {
                  _successMessage = null;
                }
              });
            },
            icon: const Icon(
              Icons.close_rounded,
              size: 17,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// SETTINGS PANEL
// ===========================================================

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: child,
    );
  }
}

// ===========================================================
// SETTINGS DETAIL ROW
// ===========================================================

class _SettingsDetailRow extends StatelessWidget {
  const _SettingsDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                value,
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
        if (onCopy != null)
          IconButton(
            tooltip: 'Copy reference',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.copy_rounded,
              size: 18,
            ),
            onPressed: onCopy,
          ),
      ],
    );
  }
}

// ===========================================================
// SETTINGS NOTICE
// ===========================================================

class _SettingsNotice extends StatelessWidget {
  const _SettingsNotice({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// PASSWORD CHANGE INPUT
// ===========================================================

class _PasswordChangeInput {
  const _PasswordChangeInput({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;
}

// ===========================================================
// CHANGE PASSWORD DIALOG
// ===========================================================

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState
    extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();

  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      _PasswordChangeInput(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _currentController,
                  obscureText: _obscureCurrent,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _obscureCurrent
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () {
                        setState(() {
                          _obscureCurrent = !_obscureCurrent;
                        });
                      },
                      icon: Icon(
                        _obscureCurrent
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter your current password.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _newController,
                  obscureText: _obscureNew,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    helperText: 'At least 8 characters',
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                    suffixIcon: IconButton(
                      tooltip: _obscureNew
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () {
                        setState(() {
                          _obscureNew = !_obscureNew;
                        });
                      },
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 8) {
                      return 'Use at least 8 characters.';
                    }

                    if (value == _currentController.text) {
                      return 'Choose a different password.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Confirm new password',
                    prefixIcon: const Icon(Icons.verified_user_outlined),
                    suffixIcon: IconButton(
                      tooltip: _obscureConfirm
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () {
                        setState(() {
                          _obscureConfirm = !_obscureConfirm;
                        });
                      },
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirm your new password.';
                    }

                    if (value != _newController.text) {
                      return 'Passwords do not match.';
                    }

                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
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
          child: const Text('Save password'),
        ),
      ],
    );
  }
}