import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

class ShopRepository {
  ShopRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  Future<bool> hasShop() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return false;
    }

    final result = await _client
        .from('shops')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();

    return result != null;
  }

  Future<void> createShop({
    required String name,
    required String currencyCode,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError(
        'A signed-in user is required to create a shop.',
      );
    }

    await _client.from('shops').insert({
      'owner_id': user.id,
      'name': name,
      'currency_code': currencyCode,
      'is_active': true,
    });
  }
}