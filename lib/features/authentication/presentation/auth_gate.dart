import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.authenticatedBuilder,
  });

  final AuthService authService;
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

    _authSubscription =
        widget.authService.authStateChanges.listen(_handleAuthState);

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

    if (state.session == null) {
      _checkVersion++;

      setState(() {
        _checkingShop = false;
        _hasShop = null;
        _errorMessage = null;
      });

      return;
    }

    // Check the shop when a session is first established.
    // Token refreshes do not require another shop lookup.
    if (state.event == AuthChangeEvent.signedIn ||
        state.event == AuthChangeEvent.initialSession) {
      _checkShop();
    }
  }

  Future<void> _checkShop() async {
    final version = ++_checkVersion;

    if (widget.authService.currentUser == null) {
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
      final hasShop = await widget.authService.hasShop();

      if (!mounted || version != _checkVersion) return;

      setState(() {
        _hasShop = hasShop;
        _checkingShop = false;
      });
    } catch (error) {
      if (!mounted || version != _checkVersion) return;

      setState(() {
        _errorMessage =
            'We could not verify your shop. Check your connection and try again.';
        _checkingShop = false;
      });

      debugPrint('SHOPFLOW: Shop verification failed: $error');
    }
  }

  Future<void> _signOut() async {
    try {
      await widget.authService.signOut();
    } catch (error) {
      debugPrint('SHOPFLOW: Sign out failed: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not sign out. Please try again.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;

    if (user == null) {
      return LoginScreen(authService: widget.authService);
    }

    if (_checkingShop || _hasShop == null && _errorMessage == null) {
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

    if (_hasShop == false) {
      return const ShopSetupPlaceholder();
    }

    return widget.authenticatedBuilder(context);
  }
}

class ShopSetupPlaceholder extends StatelessWidget {
  const ShopSetupPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Your account is ready. Shop setup is the next step.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
