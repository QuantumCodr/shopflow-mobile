import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/theme/app_colors.dart';
import '../services/auth_service.dart';

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({
    super.key,
    required this.authService,
    required this.onFinished,
  });

  final AuthService authService;
  final Future<void> Function() onFinished;

  @override
  State<UpdatePasswordScreen> createState() =>
      _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState
    extends State<UpdatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isUpdated = false;

  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (_isSaving || _isUpdated) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.completePasswordRecovery(
        newPassword: _passwordController.text,
      );

      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _isUpdated = true;
      });
    } on AuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;

      debugPrint('SHOPFLOW: Password reset failed: $error');

      setState(() {
        _isSaving = false;
        _errorMessage =
            'Could not update your password. '
            'The reset link may have expired. Request a new one if needed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              child: _isUpdated
                  ? _buildSuccess()
                  : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_reset_rounded,
            size: 60,
            color: AppColors.brand,
          ),
          const SizedBox(height: 20),
          Text(
            'Choose a new password',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Create a new password for your ShopFlow account.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _passwordController,
            enabled: !_isSaving,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'New password',
              helperText: 'At least 8 characters',
              suffixIcon: IconButton(
                tooltip: _obscurePassword
                    ? 'Show password'
                    : 'Hide password',
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.length < 8) {
                return 'Use at least 8 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmController,
            enabled: !_isSaving,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm new password',
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
              if (value != _passwordController.text) {
                return 'Passwords do not match.';
              }
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppColors.error,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSaving ? null : _updatePassword,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textOnBrand,
                    ),
                  )
                : const Text('Update password'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          size: 64,
          color: AppColors.success,
        ),
        const SizedBox(height: 20),
        Text(
          'Password updated',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your password has been changed. Return to sign in using '
          'your new password.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: widget.onFinished,
          child: const Text('Return to sign in'),
        ),
      ],
    );
  }
}