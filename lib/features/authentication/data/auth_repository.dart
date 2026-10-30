import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

class AuthRepository {
  AuthRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName.trim()},
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> resendSignupConfirmation({
    required String email,
  }) {
    return _client.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<bool> hasShop() async {
    final user = currentUser;

    if (user == null) return false;

    final result = await _client
        .from('shops')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();

    return result != null;
  }

  Future<void> sendPasswordRecoveryEmail({
    required String email,
    required String redirectTo,
  }) async {
    await _client.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      redirectTo: redirectTo,
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.auth.updateUser(
      UserAttributes(
        password: newPassword,
        currentPassword: currentPassword,
      ),
    );
  }

  Future<void> updatePasswordAfterRecovery({
    required String newPassword,
  }) async {
    await _client.auth.updateUser(
      UserAttributes(
        password: newPassword,
      ),
    );
  }

  Future<AuthSessionUrlResponse> handleAuthCallback(
    Uri callbackUri,
  ) {
    return _client.auth.getSessionFromUrl(callbackUri);
  }  

}