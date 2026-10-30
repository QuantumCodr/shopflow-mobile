import 'package:flutter/material.dart';
import 'package:shopflow_mobile/features/authentication/presentation/forgot_password_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/validation/email_validator.dart';
import '../../../shared/theme/app_colors.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
  });

  // AuthGate supplies the existing authentication service.
  final AuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _resending = false;
  bool _emailNeedsVerification = false;

  String? _errorMessage;
  String? _infoMessage;

  // Normalize the email before sending it to Supabase.
  String get _email => _emailController.text.trim().toLowerCase();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  Future<void> _openRegistration() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => RegisterScreen(
          authService: widget.authService,
        ),
      ),
    );

    if (!mounted) return;

    // Prefill the email returned by the registration screen.
    if (result != null && result.isNotEmpty) {
      _emailController.text = result;
      _passwordController.clear();

      setState(() {
        _errorMessage = null;
        _emailNeedsVerification = false;
        _infoMessage =
            'Check your email and confirm your account before signing in.';
      });
    }
  }

  Future<void> _openPasswordRecovery() async {
    FocusScope.of(context).unfocus();

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordScreen(
          authService: widget.authService,
          initialEmail: _email,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SIGN IN
  // ---------------------------------------------------------------------------

  Future<void> _signIn() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    // Validate before contacting Supabase.
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
      _emailNeedsVerification = false;
    });

    try {
      // AuthService handles authentication.
      // AuthGate listens for the resulting session change.
      await widget.authService.signIn(
        email: _email,
        password: _passwordController.text,
      );
    } catch (error, stackTrace) {
      if (!mounted) return;

      debugPrint('SHOPFLOW: Sign-in failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      final message = _friendlyError(error);
      final normalizedMessage = message.toLowerCase();

      final needsVerification =
          normalizedMessage.contains('email not confirmed') ||
          normalizedMessage.contains('email not verified') ||
          normalizedMessage.contains('confirm your email') ||
          normalizedMessage.contains('email is not confirmed');

      setState(() {
        _errorMessage = needsVerification
            ? 'Your email has not been confirmed yet. Open the verification '
                'email we sent you, or request a new one below.'
            : message;

        _emailNeedsVerification = needsVerification;
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
  // RESEND VERIFICATION
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
      _infoMessage = null;
    });

    try {
      await widget.authService.resendSignupConfirmation(
        email: _email,
      );

      if (!mounted) return;

      setState(() {
        _infoMessage =
            'If this account needs confirmation, a new verification email '
            'may arrive shortly. Check your inbox and spam folder.';

        _emailNeedsVerification = false;
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

  // ---------------------------------------------------------------------------
  // ERROR HANDLING
  // ---------------------------------------------------------------------------

  String _friendlyError(Object error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();

      if (message.contains('invalid login credentials')) {
        return 'The email or password is incorrect. '
            'Check your details and try again.';
      }

      if (message.contains('rate limit') ||
          message.contains('too many requests')) {
        return 'Too many attempts. Please wait a little before trying again.';
      }

      return error.message;
    }

    return 'Unable to sign in. Check your internet connection and try again.';
  }

  void _clearMessages() {
    if (_errorMessage == null &&
        _infoMessage == null &&
        !_emailNeedsVerification) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _infoMessage = null;
      _emailNeedsVerification = false;
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

            final compact = constraints.maxHeight < 680 ||
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Hide the brand when space is limited.
                        if (!keyboardVisible) ...[
                          _buildBrand(compact: compact),
                          SizedBox(height: compact ? 16 : 28),
                        ],

                        Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontSize: compact ? 24 : 28,
                                fontWeight: FontWeight.w700,
                              ),
                        ),

                        if (!keyboardVisible) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Sign in to continue.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],

                        SizedBox(
                          height: keyboardVisible
                              ? 12
                              : compact
                                  ? 16
                                  : 24,
                        ),

                        // EMAIL
                        TextFormField(
                          controller: _emailController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          autocorrect: false,
                          decoration: _inputDecoration(
                            label: 'Email address',
                            icon: Icons.mail_outline_rounded,
                            compact: compact,
                          ),
                          onChanged: (_) => _clearMessages(),
                          validator: (value) {
                            if (!EmailValidator.isValid(value ?? '')) {
                              return 'Enter a valid email address.';
                            }

                            return null;
                          },
                        ),

                        SizedBox(height: compact ? 10 : 16),

                        // PASSWORD
                        TextFormField(
                          controller: _passwordController,
                          enabled: !_isLoading,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [
                            AutofillHints.password,
                          ],
                          decoration: _inputDecoration(
                            label: 'Password',
                            icon: Icons.lock_outline_rounded,
                            compact: compact,
                            suffix: IconButton(
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
                            if (value == null || value.isEmpty) {
                              return 'Enter your password.';
                            }

                            return null;
                          },
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() {
                                _errorMessage = null;
                                _emailNeedsVerification = false;
                              });
                            }
                          },
                          onFieldSubmitted: (_) => _signIn(),
                        ),

                        // Secondary action.
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: Size(0, compact ? 32 : 40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _isLoading || _resending
                                ? null
                                : _openPasswordRecovery,
                            child: const Text('Forgot password?'),
                          ),
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 8),
                          _MessageBox(
                            message: _errorMessage!,
                            isError: true,
                          ),
                        ],

                        if (_infoMessage != null) ...[
                          const SizedBox(height: 8),
                          _MessageBox(
                            message: _infoMessage!,
                            isError: false,
                          ),
                        ],

                        if (_emailNeedsVerification) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed:
                                _resending ? null : _resendVerification,
                            icon: _resending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.mark_email_read_outlined,
                                  ),
                            label: Text(
                              _resending
                                  ? 'Sending verification email...'
                                  : 'Resend verification email',
                            ),
                          ),
                        ],

                        SizedBox(height: compact ? 10 : 18),

                        // Primary action.
                        FilledButton(
                          onPressed: _isLoading ? null : _signIn,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            child: _isLoading
                                ? const SizedBox(
                                    key: ValueKey('signing-in'),
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.textOnBrand,
                                    ),
                                  )
                                : const Text(
                                    'Sign in',
                                    key: ValueKey('sign-in'),
                                  ),
                          ),
                        ),

                        // Keep registration available, but hide it while
                        // the keyboard occupies most of the viewport.
                        if (!keyboardVisible) ...[
                          SizedBox(height: compact ? 4 : 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  'New to ShopFlow?',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium,
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: Size(
                                    0,
                                    compact ? 36 : 44,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: _isLoading
                                    ? null
                                    : _openRegistration,
                                child: const Text('Create account'),
                              ),
                            ],
                          ),
                        ],
                      ],
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
  // SHARED FIELD STYLING
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
            color: AppColors.textOnBrand,
            size: compact ? 23 : 27,
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