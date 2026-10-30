import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shop_setup/presentation/shop_setup_screen.dart';
import '../../shop_setup/services/shop_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'update_password_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.shopService,
    required this.authenticatedBuilder,
  });

  final AuthService authService;
  final ShopService shopService;
  final WidgetBuilder authenticatedBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;

  bool _checkingShop = false;
  bool? _hasShop;
  String? _errorMessage;

  bool _isPasswordRecovery = false;
  bool _isHandlingWebCallback = false;

  // Prevents stale shop checks from overwriting newer state.
  int _checkVersion = 0;

  @override
  void initState() {
    super.initState();

    // Listen before processing any authentication callback.
    _authSubscription = widget.authService.authStateChanges.listen(
      _handleAuthState,
    );

    if (kIsWeb) {
      // Web callbacks must be processed manually because
      // detectSessionInUri is disabled in main.dart for web.
      unawaited(_handleWebCallbackOrCheckShop());
    } else {
      // Android callbacks are handled by Supabase automatically.
      _checkShop();
    }
  }

  // =========================================================
  // WEB CALLBACK DETECTION
  // =========================================================

  bool _containsAuthCallback(Uri uri) {
    return uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('error') ||
        uri.queryParameters.containsKey('error_code') ||
        uri.queryParameters.containsKey('error_description');
  }

  Future<void> _handleWebCallbackOrCheckShop() async {
    final uri = Uri.base;

    // Normal browser launch: there is no authentication callback.
    if (!_containsAuthCallback(uri)) {
      await _checkShop();
      return;
    }

    setState(() {
      _isHandlingWebCallback = true;
      _checkingShop = true;
      _hasShop = null;
      _errorMessage = null;
    });

    try {
      // Exchange the recovery URL for a Supabase session.
      final response = await widget.authService.handleAuthCallback(uri);

      if (!mounted) return;

      final isRecovery =
          response.redirectType == AuthChangeEvent.passwordRecovery.name;

      setState(() {
        _isHandlingWebCallback = false;
        _isPasswordRecovery = isRecovery;
        _checkingShop = false;
        _hasShop = null;
        _errorMessage = null;
      });

      // Other authentication callbacks continue to normal shop checks.
      if (!isRecovery) {
        await _checkShop();
      }
    } on AuthException catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Web authentication callback failed: '
        '${error.message}\n$stackTrace',
      );

      if (!mounted) return;

      setState(() {
        _isHandlingWebCallback = false;
        _checkingShop = false;
        _hasShop = null;
        _errorMessage =
            'This authentication link is invalid or expired. '
            'Please request a new password-reset email.';
      });
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Unexpected web callback error: '
        '$error\n$stackTrace',
      );

      if (!mounted) return;

      setState(() {
        _isHandlingWebCallback = false;
        _checkingShop = false;
        _hasShop = null;
        _errorMessage =
            'We could not complete password recovery. '
            'Please request a new reset email.';
      });
    }
  }

  // =========================================================
  // AUTHENTICATION EVENTS
  // =========================================================

  void _handleAuthState(AuthState state) {
    debugPrint(
      'SHOPFLOW AUTH EVENT: '
      'event=${state.event}, '
      'eventHasSession=${state.session != null}, '
      'currentUser=${widget.authService.currentUser?.id ?? "null"}',
    );

    if (!mounted) return;

    // PASSWORD RECOVERY
    if (state.event == AuthChangeEvent.passwordRecovery &&
        state.session != null) {
      _checkVersion++;

      setState(() {
        _isPasswordRecovery = true;
        _checkingShop = false;
        _hasShop = null;
        _errorMessage = null;
      });

      return;
    }

    // SESSION ENDED
    if (state.session == null) {
      _checkVersion++;

      setState(() {
        _isPasswordRecovery = false;
        _checkingShop = false;
        _hasShop = null;
        _errorMessage = null;
      });

      return;
    }

    // Avoid normal shop navigation while a web callback
    // is being processed.
    if (_isHandlingWebCallback) return;

    // Do not enter the normal application during recovery.
    if (_isPasswordRecovery) return;

    if (state.event == AuthChangeEvent.signedIn ||
        state.event == AuthChangeEvent.initialSession) {
      _checkShop();
    }
  }

  // =========================================================
  // SHOP VERIFICATION
  // =========================================================

  Future<void> _checkShop() async {
    if (_isPasswordRecovery || _isHandlingWebCallback) return;

    final version = ++_checkVersion;

    final user = widget.authService.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _checkingShop = false;
        _hasShop = null;
        _errorMessage = null;
      });

      return;
    }

    setState(() {
      _checkingShop = true;
      _hasShop = null;
      _errorMessage = null;
    });

    try {
      final hasShop = await widget.shopService.hasShop();

      if (!mounted || version != _checkVersion) return;
      if (_isPasswordRecovery) return;

      setState(() {
        _hasShop = hasShop;
        _checkingShop = false;
      });
    } catch (error, stackTrace) {
      if (!mounted || version != _checkVersion) return;
      if (_isPasswordRecovery) return;

      debugPrint(
        'SHOPFLOW: Shop verification failed: '
        '$error\n$stackTrace',
      );

      setState(() {
        _errorMessage =
            'We could not verify your shop. '
            'Check your connection and try again.';
        _checkingShop = false;
      });
    }
  }

  // =========================================================
  // SIGN OUT
  // =========================================================

  Future<void> _signOut() async {
    try {
      await widget.authService.signOut();
    } catch (error, stackTrace) {
      debugPrint('SHOPFLOW: Sign out failed: $error\n$stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    }
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;

    // 1. PASSWORD RECOVERY
    if (_isPasswordRecovery && user != null) {
      return UpdatePasswordScreen(
        authService: widget.authService,
        onFinished: _signOut,
      );
    }

    // 2. WEB CALLBACK PROCESSING
    if (_isHandlingWebCallback) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verifying password-reset link...'),
            ],
          ),
        ),
      );
    }

    // 3. ERROR
    if (_errorMessage != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 56),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _checkShop,
                      child: const Text('Try again'),
                    ),
                    TextButton(
                      onPressed: _signOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 4. NO AUTHENTICATED USER
    if (user == null) {
      return LoginScreen(authService: widget.authService);
    }

    // 5. SHOP VERIFICATION LOADING
    if (_checkingShop || _hasShop == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Getting your shop ready...'),
            ],
          ),
        ),
      );
    }

    // 6. USER HAS NOT CREATED A SHOP
    if (_hasShop == false) {
      return ShopSetupScreen(
        shopService: widget.shopService,
        onShopCreated: _checkShop,
        onSignOut: _signOut,
      );
    }

    // 7. AUTHENTICATED USER WITH A SHOP
    return widget.authenticatedBuilder(context);
  }
}
