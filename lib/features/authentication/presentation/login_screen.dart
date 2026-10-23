import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
  });

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

  String get _email => _emailController.text.trim().toLowerCase();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _openRegistration() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => RegisterScreen(
          authService: widget.authService,
        ),
      ),
    );

    if (!mounted) return;

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

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
      _emailNeedsVerification = false;
    });

    try {
      await widget.authService.signIn(
        email: _email,
        password: _passwordController.text,
      );
    } catch (error) {
      if (!mounted) return;

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
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendVerification() async {
    if (_email.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email)) {
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
      await widget.authService.resendSignupConfirmation(email: _email);

      if (!mounted) return;

      setState(() {
        _infoMessage =
            'If this account needs confirmation, a new verification email '
            'may arrive shortly. Check your inbox and spam folder.';
        _emailNeedsVerification = false;
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

  String _friendlyError(Object error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();

      if (message.contains('invalid login credentials')) {
        return 'The email or password is incorrect. Check your details and try again.';
      }

      if (message.contains('rate limit') ||
          message.contains('too many requests')) {
        return 'Too many attempts. Please wait a little before trying again.';
      }

      return error.message;
    }

    return 'Unable to sign in. Check your internet connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      size: 68,
                      color: Color(0xFF176B55),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Sign in to manage your shop.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        if (_emailNeedsVerification || _errorMessage != null) {
                          setState(() {
                            _emailNeedsVerification = false;
                            _errorMessage = null;
                          });
                        }
                      },
                      validator: (value) {
                        final email = value?.trim() ?? '';

                        if (email.isEmpty) {
                          return 'Enter your email address.';
                        }

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
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter your password.';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _signIn(),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _MessageBox(
                        message: _errorMessage!,
                        isError: true,
                      ),
                    ],

                    if (_infoMessage != null) ...[
                      const SizedBox(height: 16),
                      _MessageBox(
                        message: _infoMessage!,
                        isError: false,
                      ),
                    ],

                    if (_emailNeedsVerification) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _resending ? null : _resendVerification,
                        icon: const Icon(Icons.mark_email_read_outlined),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _resending
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Resend verification email'),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    FilledButton(
                      onPressed: _isLoading ? null : _signIn,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Sign in'),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: _isLoading ? null : _openRegistration,
                      child: const Text("New to ShopFlow? Create an account"),
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
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(color: color),
      ),
    );
  }
}