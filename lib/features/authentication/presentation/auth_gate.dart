import 'dart:async';

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

  // True while the user is completing a password-reset flow.
  bool _isPasswordRecovery = false;

  // Prevents stale shop-check requests from overwriting newer state.
  int _checkVersion = 0;

  @override
  void initState() {
    super.initState();

    // Listen for Supabase authentication events.
    _authSubscription =
        widget.authService.authStateChanges.listen(
      _handleAuthState,
    );

    // Check shop status for an existing authenticated session.
    _checkShop();
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
    //
    // Supabase emits this event when the user enters the password
    // recovery flow through a valid recovery link.
    //
    // Do not perform the regular shop check during recovery.
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
    //
    // This also handles the sign-out performed after a successful
    // password reset.
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

    // Do not send the user into the normal shop flow while
    // they are completing password recovery.
    if (_isPasswordRecovery) return;

    // Verify shop status when a session is established.
    // A routine token refresh doesn't require another shop lookup.
    if (state.event == AuthChangeEvent.signedIn ||
        state.event == AuthChangeEvent.initialSession) {
      _checkShop();
    }
  }

  // =========================================================
  // SHOP VERIFICATION
  // =========================================================

  Future<void> _checkShop() async {
    // Never perform the normal shop verification during recovery.
    if (_isPasswordRecovery) return;

    // Identify this request so an older result cannot overwrite
    // a newer authentication or shop-verification result.
    final version = ++_checkVersion;

    // No signed-in user means there is no shop to check.
    if (widget.authService.currentUser == null) {
      if (!mounted) return;

      setState(() {
        _checkingShop = false;
        _hasShop = null;
        _errorMessage = null;
      });

      return;
    }

    // Show the loading state while checking Supabase.
    setState(() {
      _checkingShop = true;
      _hasShop = null;
      _errorMessage = null;
    });

    try {
      // Shop verification belongs to ShopService.
      final hasShop = await widget.shopService.hasShop();

      // Ignore outdated results.
      if (!mounted || version != _checkVersion) return;

      // Recovery might have started while the request was running.
      if (_isPasswordRecovery) return;

      setState(() {
        _hasShop = hasShop;
        _checkingShop = false;
      });
    } catch (error, stackTrace) {
      if (!mounted || version != _checkVersion) return;

      if (_isPasswordRecovery) return;

      setState(() {
        _errorMessage =
            'We could not verify your shop. '
            'Check your connection and try again.';
        _checkingShop = false;
      });

      debugPrint(
        'SHOPFLOW: Shop verification failed: $error\n$stackTrace',
      );
    }
  }

  // =========================================================
  // SIGN OUT
  // =========================================================

  Future<void> _signOut() async {
    try {
      await widget.authService.signOut();

      // Supabase's authentication stream will notify AuthGate
      // when the session is cleared.
      //
      // _handleAuthState resets the recovery state and returns
      // the user to the LoginScreen.
    } catch (error, stackTrace) {
      debugPrint(
        'SHOPFLOW: Sign out failed: $error\n$stackTrace',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not sign out. Please try again.',
          ),
        ),
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
    //
    // Show the new-password form before the normal authenticated
    // application or shop-setup flow.
    if (_isPasswordRecovery && user != null) {
      return UpdatePasswordScreen(
        authService: widget.authService,
        onFinished: _signOut,
      );
    }

    // 2. NO AUTHENTICATED USER
    if (user == null) {
      return LoginScreen(
        authService: widget.authService,
      );
    }

    // 3. SHOP VERIFICATION LOADING
    if (_checkingShop ||
        (_hasShop == null && _errorMessage == null)) {
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

    // 4. SHOP VERIFICATION FAILED
    if (_errorMessage != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 400,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 56,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                    ),

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

    // 5. USER HAS NOT CREATED A SHOP
    if (_hasShop == false) {
      return ShopSetupScreen(
        shopService: widget.shopService,
        onShopCreated: _checkShop,
        onSignOut: _signOut,
      );
    }

    // 6. AUTHENTICATED USER WITH A SHOP
    return widget.authenticatedBuilder(context);
  }
}