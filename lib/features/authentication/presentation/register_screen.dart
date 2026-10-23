import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.authService,
  });

  final AuthService authService;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _awaitingVerification = false;
  bool _resending = false;

  String? _errorMessage;
  String? _resendMessage;

  String get _email => _emailController.text.trim().toLowerCase();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await widget.authService.register(
        fullName: _nameController.text,
        email: _email,
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (response.session != null) {
        // Supabase has already authenticated the customer.
        // AuthGate will handle the authenticated state.
        Navigator.of(context).pop();
        return;
      }

      setState(() {
        _awaitingVerification = true;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendVerification() async {
    setState(() {
      _resending = true;
      _resendMessage = null;
      _errorMessage = null;
    });

    try {
      await widget.authService.resendSignupConfirmation(email: _email);

      if (!mounted) return;

      setState(() {
        _resendMessage =
            'If this address has a pending registration, a new '
            'verification email may arrive shortly. Check your inbox '
            'and spam folder.';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _resending = false);
      }
    }
  }

  void _continueToLogin() {
    Navigator.of(context).pop(_email);
  }

  String _friendlyError(Object error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();

      if (message.contains('already registered') ||
          message.contains('already exists')) {
        return 'An account may already exist for this email. '
            'Try signing in or use another email address.';
      }

      if (message.contains('rate limit') ||
          message.contains('too many requests')) {
        return 'Too many attempts. Please wait a little before trying again.';
      }

      return error.message;
    }

    return 'Something went wrong. Check your internet connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _awaitingVerification ? 'Verify your email' : 'Create account',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _awaitingVerification
                    ? _buildVerificationContent()
                    : _buildRegistrationForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('registration-form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BrandHeader(
            icon: Icons.storefront_rounded,
            title: 'Start with ShopFlow',
            subtitle: 'Create your account and start managing your shop.',
          ),
          const SizedBox(height: 28),

          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: _inputDecoration(
              label: 'Full name',
              icon: Icons.person_outline,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter your full name.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: _inputDecoration(
              label: 'Email address',
              icon: Icons.email_outlined,
            ),
            validator: (value) {
              final email = value?.trim() ?? '';

              if (email.isEmpty) return 'Enter your email address.';

              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                  .hasMatch(email)) {
                return 'Enter a valid email address.';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: _inputDecoration(
              label: 'Password',
              icon: Icons.lock_outline,
              suffix: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
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
            controller: _confirmPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            decoration: _inputDecoration(
              label: 'Confirm password',
              icon: Icons.lock_reset_outlined,
            ),
            onFieldSubmitted: (_) => _register(),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Passwords do not match.';
              }
              return null;
            },
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _MessageBox(
              message: _errorMessage!,
              isError: true,
            ),
          ],

          const SizedBox(height: 24),

          FilledButton(
            onPressed: _isLoading ? null : _register,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create account'),
            ),
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: _isLoading ? null : _continueToLogin,
            child: const Text('Already have an account? Sign in'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationContent() {
    return Column(
      key: const ValueKey('verification-screen'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 76,
          color: Color(0xFF176B55),
        ),
        const SizedBox(height: 24),

        Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),

        const Text(
          'We have submitted your registration. Open the verification '
          'email from Supabase and tap its confirmation link to activate '
          'your account.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.email_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _email,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'Check your spam folder too. After confirming your email, '
          'return here to sign in.',
          textAlign: TextAlign.center,
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _MessageBox(message: _errorMessage!, isError: true),
        ],

        if (_resendMessage != null) ...[
          const SizedBox(height: 16),
          _MessageBox(message: _resendMessage!, isError: false),
        ],

        const SizedBox(height: 24),

        FilledButton.icon(
          onPressed: _continueToLogin,
          icon: const Icon(Icons.login),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Continue to sign in'),
          ),
        ),

        const SizedBox(height: 8),

        OutlinedButton(
          onPressed: _resending ? null : _resendVerification,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _resending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Resend verification email'),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      border: const OutlineInputBorder(),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 64,
          color: const Color(0xFF176B55),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Theme.of(context).colorScheme.error
        : const Color(0xFF176B55);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: TextStyle(color: color),
      ),
    );
  }
}