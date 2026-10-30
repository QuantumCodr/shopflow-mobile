import 'package:flutter/material.dart';

import '../../../core/validation/email_validator.dart';
import '../../../shared/theme/app_colors.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.authService,
    this.initialEmail = '',
  });

  final AuthService authService;
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  bool _isSending = false;
  bool _emailSent = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _emailController = TextEditingController(
      text: widget.initialEmail,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (_isSending) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.sendPasswordRecoveryEmail(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isSending = false;
        _emailSent = true;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isSending = false;
        _errorMessage =
            'We could not send the reset request. '
            'Please check your connection and try again.';
      });

      debugPrint('SHOPFLOW: Password recovery request failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Forgot password'),
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.textOnBrand,
      ),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                ),
                child: _emailSent
                    ? _buildSuccess()
                    : _buildForm(),
              ),
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
            'Reset your password',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Enter the email address associated with your ShopFlow account. '
            'We will send instructions for resetting your password.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            enabled: !_isSending,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: (value) {
              if (!EmailValidator.isValid(value ?? '')) {
                return 'Enter a valid email address.';
              }
              return null;
            },
            onFieldSubmitted: (_) => _sendResetEmail(),
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
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSending ? null : _sendResetEmail,
            child: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textOnBrand,
                    ),
                  )
                : const Text('Send reset email'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isSending
                ? null
                : () => Navigator.of(context).pop(),
            child: const Text('Back to sign in'),
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
          Icons.mark_email_read_outlined,
          size: 60,
          color: AppColors.success,
        ),
        const SizedBox(height: 20),
        Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          'If an account exists for this email address, you should '
          'receive instructions to reset its password. Check your inbox '
          'and spam folder.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }
}