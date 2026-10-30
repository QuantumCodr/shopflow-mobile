import '../../authentication/services/auth_service.dart';
import '../data/settings_repository.dart';
import '../models/settings_models.dart';

class SettingsServiceException implements Exception {
  const SettingsServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SettingsService {
  SettingsService({
    SettingsRepository? repository,
    AuthService? authService,
  })  : _repository = repository ?? SettingsRepository(),
        _authService = authService ?? AuthService();

  final SettingsRepository _repository;
  final AuthService _authService;

  Future<SettingsSnapshot> loadSettings() async {
    try {
      final user = _authService.currentUser;

      if (user == null) {
        throw const SettingsServiceException(
          'Please sign in to view your settings.',
        );
      }

      final shop = await _repository.getActiveShop();

      return SettingsSnapshot(
        accountEmail: user.email ?? '',
        shop: shop,
      );
    } on SettingsServiceException {
      rethrow;
    } on SettingsRepositoryException catch (error) {
      throw SettingsServiceException(error.message);
    } catch (error) {
      throw SettingsServiceException(
        'Could not load settings: $error',
      );
    }
  }

  Future<ShopSettings> updateShopName(String name) async {
    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw const SettingsServiceException(
        'Enter a shop name.',
      );
    }

    if (normalizedName.length > 100) {
      throw const SettingsServiceException(
        'The shop name cannot exceed 100 characters.',
      );
    }

    try {
      final shop = await _repository.getActiveShop();

      return await _repository.updateShopName(
        shopId: shop.id,
        name: normalizedName,
      );
    } on SettingsServiceException {
      rethrow;
    } on SettingsRepositoryException catch (error) {
      throw SettingsServiceException(error.message);
    } catch (error) {
      throw SettingsServiceException(
        'Could not update the shop name: $error',
      );
    }
  }

  Future<void> sendPasswordRecoveryEmail() async {
    try {
      final email = _authService.currentUser?.email;

      if (email == null || email.trim().isEmpty) {
        throw const SettingsServiceException(
          'Your account does not have an available email address.',
        );
      }

      await _authService.sendPasswordRecoveryEmail(
        email: email,
      );
    } on SettingsServiceException {
      rethrow;
    } catch (error) {
      throw SettingsServiceException(
        'Could not request password recovery: $error',
      );
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } catch (error) {
      throw SettingsServiceException(
        error.toString(),
      );
    }
  }  
}