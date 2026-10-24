import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shop_setup/presentation/shop_setup_screen.dart';
import '../../shop_setup/services/shop_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

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

  int _checkVersion = 0;

  @override
  void initState() {
    super.initState();

    // Listen for authentication changes.
    _authSubscription =
        widget.authService.authStateChanges.listen(_handleAuthState);

    // Check whether the current user has a shop.
    _checkShop();
  }

  void _handleAuthState(AuthState state) {
    debugPrint(
      'SHOPFLOW AUTH EVENT: '
      'event=${state.event}, '
      'eventHasSession=${state.session != null}, '
      'currentUser=${widget.authService.currentUser?.id ?? "null"}',
    );

    if (!mounted) return;

    // When the session disappears, reset the shop-check state.
    if (state.session == null) {
      _checkVersion++;

      setState(() {
        _checkingShop = false;
        _hasShop = null;
        _errorMessage = null;
      });

      return;
    }

    // Verify shop status when a session is first established.
    // Token refreshes do not require another shop lookup.
    if (state.event == AuthChangeEvent.signedIn ||
        state.event == AuthChangeEvent.initialSession) {
      _checkShop();
    }
  }

  Future<void> _checkShop() async {
    // Identify this particular check so older requests
    // cannot overwrite results from newer requests.
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

    // Display the loading state while checking Supabase.
    setState(() {
      _checkingShop = true;
      _hasShop = null;
      _errorMessage = null;
    });

    try {
      // Shop-related queries belong to ShopService.
      final hasShop = await widget.shopService.hasShop();

      // Ignore results if the widget was disposed or
      // a newer shop check has already started.
      if (!mounted || version != _checkVersion) return;

      setState(() {
        _hasShop = hasShop;
        _checkingShop = false;
      });
    } catch (error, stackTrace) {
      if (!mounted || version != _checkVersion) return;

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

  Future<void> _signOut() async {
    try {
      await widget.authService.signOut();

      // Supabase's authentication stream will notify AuthGate
      // when the session has been cleared.
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

  @override
  void dispose() {
    // Stop listening when this state object is disposed.
    _authSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;

    // 1. No authenticated user: display Login.
    if (user == null) {
      return LoginScreen(
        authService: widget.authService,
      );
    }

    // 2. Shop verification is still running.
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

    // 3. Shop verification failed.
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

    // 4. The user is signed in but has not created a shop.
    if (_hasShop == false) {
      return ShopSetupScreen(
        shopService: widget.shopService,
        onShopCreated: _checkShop,
        onSignOut: _signOut,
      );
    }

    // 5. The user is signed in and has a shop.
    return widget.authenticatedBuilder(context);
  }
}