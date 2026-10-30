import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../models/settings_models.dart';

class SettingsRepositoryException implements Exception {
  const SettingsRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SettingsRepository {
  SettingsRepository({
    SupabaseClient? client,
  }) : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  String _requireUserId() {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw const SettingsRepositoryException(
        'Please sign in to manage your settings.',
      );
    }

    return user.id;
  }

  Future<ShopSettings> getActiveShop() async {
    final userId = _requireUserId();

    try {
      final response = await _client
          .from('shops')
          .select('id, name, currency_code, is_active')
          .eq('owner_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        throw const SettingsRepositoryException(
          'No active shop was found for this account.',
        );
      }

      return ShopSettings.fromMap(
        Map<String, dynamic>.from(response),
      );
    } on SettingsRepositoryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw SettingsRepositoryException(
        'Could not load your shop settings: ${error.message}',
      );
    }
  }

  Future<ShopSettings> updateShopName({
    required String shopId,
    required String name,
  }) async {
    final userId = _requireUserId();

    try {
      final response = await _client
          .from('shops')
          .update({
            'name': name.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', shopId)
          .eq('owner_id', userId)
          .eq('is_active', true)
          .select('id, name, currency_code, is_active')
          .maybeSingle();

      if (response == null) {
        throw const SettingsRepositoryException(
          'Your shop could not be updated. '
          'Verify that it is still active and try again.',
        );
      }

      return ShopSettings.fromMap(
        Map<String, dynamic>.from(response),
      );
    } on SettingsRepositoryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw SettingsRepositoryException(
        'Could not update your shop name: ${error.message}',
      );
    }
  }
}