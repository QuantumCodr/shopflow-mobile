import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

class AuthService {
  AuthService({AuthRepository? repository})
      : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  User? get currentUser => _repository.currentUser;

  Stream<AuthState> get authStateChanges =>
      _repository.authStateChanges;

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

    if (!_isValidEmail(normalizedEmail)) {
      throw const AuthException('Please enter a valid email address.');
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

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final stopwatch = Stopwatch()..start();

    final normalizedEmail = email.trim().toLowerCase();

    if (!_isValidEmail(normalizedEmail)) {
      throw const AuthException('Please enter a valid email address.');
    }

    if (password.isEmpty) {
      throw const AuthException('Please enter your password.');
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

  Future<void> resendSignupConfirmation({
    required String email,
  }) async {
    final normalizedEmail = _normalizeEmail(email);

    if (!_isValidEmail(normalizedEmail)) {
      throw const AuthException('Please enter a valid email address.');
    }

    await _repository.resendSignupConfirmation(
      email: normalizedEmail,
    );
  }

  Future<bool> hasShop() => _repository.hasShop();

  Future<void> signOut() => _repository.signOut();

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }
}