import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/validation/email_validator.dart';
import '../data/auth_repository.dart';

class AuthService {
  AuthService({AuthRepository? repository})
      : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  // Exposes the currently authenticated user.
  User? get currentUser => _repository.currentUser;

  // Exposes authentication changes from Supabase.
  Stream<AuthState> get authStateChanges =>
      _repository.authStateChanges;

  /// Creates a new user account.
  Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final normalizedName = fullName.trim();
    final normalizedEmail = _normalizeEmail(email);

    if (normalizedName.isEmpty) {
      throw const AuthException('Please enter your full name.');
    }

    if (!EmailValidator.isValid(normalizedEmail)) {
      throw const AuthException(
        'Please enter a valid email address.',
      );
    }

    if (password.length < 8) {
      throw const AuthException(
        'Your password must contain at least 8 characters.',
      );
    }

    return _repository.register(
      fullName: normalizedName,
      email: normalizedEmail,
      password: password,
    );
  }

  /// Signs in an existing user.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final stopwatch = Stopwatch()..start();

    final normalizedEmail = _normalizeEmail(email);

    if (!EmailValidator.isValid(normalizedEmail)) {
      throw const AuthException(
        'Please enter a valid email address.',
      );
    }

    if (password.isEmpty) {
      throw const AuthException(
        'Please enter your password.',
      );
    }

    try {
      final response = await _repository.signIn(
        email: normalizedEmail,
        password: password,
      );

      debugPrint(
        'SHOPFLOW: Supabase login completed in '
        '${stopwatch.elapsedMilliseconds} ms',
      );

      return response;
    } finally {
      stopwatch.stop();
    }
  }

  /// Resends the signup confirmation email.
  Future<void> resendSignupConfirmation({
    required String email,
  }) async {
    final normalizedEmail = _normalizeEmail(email);

    if (!EmailValidator.isValid(normalizedEmail)) {
      throw const AuthException(
        'Please enter a valid email address.',
      );
    }

    await _repository.resendSignupConfirmation(
      email: normalizedEmail,
    );
  }

  /// Checks whether the current user owns a shop.
  Future<bool> hasShop() => _repository.hasShop();

  /// Signs out the current user.
  Future<void> signOut() => _repository.signOut();

  /// Trims whitespace and makes the email lowercase.
  String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }


  /// Requests a password-reset email for the supplied address.
  Future<void> sendPasswordRecoveryEmail({
    required String email,
  }) async {
    final normalizedEmail = _normalizeEmail(email);

    if (!EmailValidator.isValid(normalizedEmail)) {
      throw const AuthException(
        'Please enter a valid email address.',
      );
    }
    final redirectTo = kIsWeb
        ? '${Uri.base.origin}/'
        : 'io.shopflow.app://reset-password';


    await _repository.sendPasswordRecoveryEmail(
      email: normalizedEmail,
      redirectTo: redirectTo,
    );
  }

  /// Changes the password for the currently signed-in account.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentUser == null) {
      throw const AuthException(
        'Please sign in before changing your password.',
      );
    }

    if (currentPassword.isEmpty) {
      throw const AuthException(
        'Enter your current password.',
      );
    }

    if (newPassword.length < 8) {
      throw const AuthException(
        'Your new password must contain at least 8 characters.',
      );
    }

    if (currentPassword == newPassword) {
      throw const AuthException(
        'Your new password must be different from your current password.',
      );
    }

    await _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// Sets a new password after a successful recovery-link flow.
  Future<void> completePasswordRecovery({
    required String newPassword,
  }) async {
    if (currentUser == null) {
      throw const AuthException(
        'Your password recovery session is missing or expired. '
        'Please request a new reset email.',
      );
    }

    if (newPassword.length < 8) {
      throw const AuthException(
        'Your new password must contain at least 8 characters.',
      );
    }

    await _repository.updatePasswordAfterRecovery(
      newPassword: newPassword,
    );
  }  

  Future<AuthSessionUrlResponse> handleAuthCallback(
    Uri callbackUri,
  ) {
    return _repository.handleAuthCallback(callbackUri);
  }  
}