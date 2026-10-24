import 'package:flutter/material.dart';

import 'features/authentication/presentation/auth_gate.dart';
import 'features/authentication/services/auth_service.dart';
import 'features/shell/presentation/shopflow_shell.dart';
import 'features/shop_setup/services/shop_service.dart';
import 'shared/theme/app_theme.dart';

/// Configures and launches the ShopFlow application.
///
/// Responsibilities:
/// - Set the application title and theme.
/// - Initialize the authentication and shop services.
/// - Use AuthGate to determine which screen the user should see.
///
/// Screen layouts and application navigation belong in their
/// respective feature files, not in this file.
class ShopFlowApp extends StatelessWidget {
  const ShopFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShopFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AuthGate(
        authService: AuthService(),
        shopService: ShopService(),
        authenticatedBuilder: (_) => const ShopFlowShell(),
      ),
    );
  }
}