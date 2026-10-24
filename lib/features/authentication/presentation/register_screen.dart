import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/validation/email_validator.dart';
import '../../../shared/theme/app_colors.dart';
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
  bool _obscureConfirmPassword = true;
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

  // ---------------------------------------------------------------------------
  // REGISTRATION
  // ---------------------------------------------------------------------------

  Future<void> _register() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _resendMessage = null;
    });

    try {
      final response = await widget.authService.register(
        fullName: _nameController.text,
        email: _email,
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (response.session != null) {
        // Supabase authenticated the user immediately.
        // AuthGate handles the next screen.
        Navigator.of(context).pop();
        return;
      }

      // No session: show the verification instructions.
      setState(() {
        _awaitingVerification = true;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;

      debugPrint('SHOPFLOW: Registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      setState(() {
        _errorMessage = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // EMAIL VERIFICATION
  // ---------------------------------------------------------------------------

  Future<void> _resendVerification() async {
    if (_resending) return;

    if (!EmailValidator.isValid(_email)) {
      setState(() {
        _errorMessage = 'Enter a valid email address first.';
      });
      return;
    }

    setState(() {
      _resending = true;
      _errorMessage = null;
      _resendMessage = null;
    });

    try {
      await widget.authService.resendSignupConfirmation(
        email: _email,
      );

      if (!mounted) return;

      setState(() {
        _resendMessage =
            'If this address has a pending registration, a new '
            'verification email may arrive shortly. Check your inbox '
            'and spam folder.';
      });
    } catch (error, stackTrace) {
      if (!mounted) return;

      debugPrint('SHOPFLOW: Verification resend failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      setState(() {
        _errorMessage = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _resending = false;
        });
      }
    }
  }

  void _continueToLogin() {
    // Return the email to Login so the user doesn't have to retype it.
    Navigator.of(context).pop(_email);
  }

  // ---------------------------------------------------------------------------
  // ERROR HANDLING
  // ---------------------------------------------------------------------------

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

    return 'Something went wrong. '
        'Check your internet connection and try again.';
  }

  void _clearError() {
    if (_errorMessage == null) return;

    setState(() {
      _errorMessage = null;
    });
  }

  // ---------------------------------------------------------------------------
  // RESPONSIVE LAYOUT — NO SCROLL VIEW
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboardVisible =
                MediaQuery.viewInsetsOf(context).bottom > 0;

            final compact = constraints.maxHeight < 700 ||
                keyboardVisible;

            final tight = constraints.maxHeight < 430;

            final horizontalPadding =
                constraints.maxWidth < 360 ? 20.0 : 24.0;

            final verticalPadding = keyboardVisible
                ? 2.0
                : tight
                    ? 4.0
                    : compact
                        ? 8.0
                        : 24.0;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 400,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _awaitingVerification
                        ? _buildVerificationContent(
                            compact: compact,
                            keyboardVisible: keyboardVisible,
                          )
                        : _buildRegistrationForm(
                            compact: compact,
                            keyboardVisible: keyboardVisible,
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REGISTRATION FORM
  // ---------------------------------------------------------------------------

  Widget _buildRegistrationForm({
    required bool compact,
    required bool keyboardVisible,
  }) {
    final fieldSpacing = compact ? 10.0 : 16.0;
    final headingSpacing = compact ? 16.0 : 24.0;

    return AutofillGroup(
      key: const ValueKey('registration-form'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hide branding when the keyboard needs the available space.
            if (!keyboardVisible) ...[
              _buildBrand(compact: compact),
              SizedBox(height: headingSpacing),
            ],

            Text(
              'Create your account',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: compact ? 23 : 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
            ),

            if (!keyboardVisible) ...[
              const SizedBox(height: 6),
              Text(
                'Get started with ShopFlow.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],

            SizedBox(
              height: keyboardVisible ? 10 : headingSpacing,
            ),

            // FULL NAME
            TextFormField(
              controller: _nameController,
              enabled: !_isLoading,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.name,
              ],
              decoration: _inputDecoration(
                label: 'Full name',
                icon: Icons.person_outline_rounded,
                compact: compact,
              ),
              onChanged: (_) => _clearError(),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your full name.';
                }

                return null;
              },
            ),

            SizedBox(height: fieldSpacing),

            // EMAIL ADDRESS
            TextFormField(
              controller: _emailController,
              enabled: !_isLoading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.email,
              ],
              autocorrect: false,
              decoration: _inputDecoration(
                label: 'Email address',
                icon: Icons.mail_outline_rounded,
                compact: compact,
              ),
              onChanged: (_) => _clearError(),
              validator: (value) {
                if (!EmailValidator.isValid(value ?? '')) {
                  return 'Enter a valid email address.';
                }

                return null;
              },
            ),

            SizedBox(height: fieldSpacing),

            // PASSWORD
            TextFormField(
              controller: _passwordController,
              enabled: !_isLoading,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.newPassword,
              ],
              decoration: _inputDecoration(
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                compact: compact,
                suffix: IconButton(
                  tooltip:
                      _obscurePassword ? 'Show password' : 'Hide password',
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
              onChanged: (_) => _clearError(),
              validator: (value) {
                if (value == null || value.length < 8) {
                  return 'Use at least 8 characters.';
                }

                return null;
              },
            ),

            SizedBox(height: fieldSpacing),

            // CONFIRM PASSWORD
            TextFormField(
              controller: _confirmPasswordController,
              enabled: !_isLoading,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [
                AutofillHints.newPassword,
              ],
              decoration: _inputDecoration(
                label: 'Confirm password',
                icon: Icons.lock_reset_outlined,
                compact: compact,
                suffix: IconButton(
                  tooltip: _obscureConfirmPassword
                      ? 'Show password'
                      : 'Hide password',
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword =
                          !_obscureConfirmPassword;
                    });
                  },
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              onChanged: (_) => _clearError(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirm your password.';
                }

                if (value != _passwordController.text) {
                  return 'Passwords do not match.';
                }

                return null;
              },
              onFieldSubmitted: (_) => _register(),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              _StatusMessage(
                message: _errorMessage!,
                isError: true,
              ),
            ],

            SizedBox(height: compact ? 12 : 20),

            // PRIMARY ACTION
            FilledButton(
              onPressed: _isLoading ? null : _register,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: _isLoading
                    ? const SizedBox(
                        key: ValueKey('register-loading'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnBrand,
                        ),
                      )
                    : const Text(
                        'Create account',
                        key: ValueKey('register-button'),
                      ),
              ),
            ),

            // Hide the secondary action while the keyboard is open.
            if (!keyboardVisible) ...[
              SizedBox(height: compact ? 4 : 12),
              TextButton(
                onPressed: _isLoading ? null : _continueToLogin,
                child: const Text('Already have an account? Sign in'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED INPUT STYLING
  // ---------------------------------------------------------------------------

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required bool compact,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      isDense: compact,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compact ? 12 : 16,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMAIL VERIFICATION
  // ---------------------------------------------------------------------------

  Widget _buildVerificationContent({
    required bool compact,
    required bool keyboardVisible,
  }) {
    final spacing = compact ? 16.0 : 24.0;

    return Column(
      key: const ValueKey('verification-screen'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!keyboardVisible) ...[
          _buildBrand(compact: compact),
          SizedBox(height: spacing),
        ],

        Icon(
          Icons.mark_email_read_outlined,
          size: compact ? 44 : 56,
          color: AppColors.brand,
        ),

        const SizedBox(height: 16),

        Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: compact ? 23 : 28,
                fontWeight: FontWeight.w700,
              ),
        ),

        const SizedBox(height: 10),

        Text(
          'Confirm your email address using the verification link '
          'we sent you.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
        ),

        SizedBox(height: spacing),

        // Identify the email address without adding another card.
        Text(
          _email,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
        ),

        const SizedBox(height: 12),

        Text(
          'Check your spam folder too. After confirming your email, '
          'return here to sign in.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          _StatusMessage(
            message: _errorMessage!,
            isError: true,
          ),
        ],

        if (_resendMessage != null) ...[
          const SizedBox(height: 12),
          _StatusMessage(
            message: _resendMessage!,
            isError: false,
          ),
        ],

        SizedBox(height: spacing),

        FilledButton(
          onPressed: _continueToLogin,
          child: const Text('Continue to sign in'),
        ),

        if (!keyboardVisible) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _resending ? null : _resendVerification,
            child: _resending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Resend verification email'),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BRAND MARK
  // ---------------------------------------------------------------------------

  Widget _buildBrand({
    required bool compact,
  }) {
    final size = compact ? 40.0 : 48.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.storefront_rounded,
            size: compact ? 23 : 27,
            color: AppColors.textOnBrand,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ShopFlow',
          style: TextStyle(
            fontSize: compact ? 19 : 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// STATUS MESSAGE
// -----------------------------------------------------------------------------

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? AppColors.error
        : AppColors.brand;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 19,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}