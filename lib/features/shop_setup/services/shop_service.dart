import '../data/shop_repository.dart';

class ShopService {
  ShopService({ShopRepository? repository})
      : _repository = repository ?? ShopRepository();

  final ShopRepository _repository;

  Future<bool> hasShop() {
    return _repository.hasShop();
  }

  Future<void> createShop({
    required String name,
  }) async {
    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw const ShopValidationException(
        'Please enter your shop name.',
      );
    }

    if (normalizedName.length > 100) {
      throw const ShopValidationException(
        'Your shop name must be 100 characters or fewer.',
      );
    }

    await _repository.createShop(
      name: normalizedName,
      currencyCode: 'SLE',
    );
  }
}

class ShopValidationException implements Exception {
  const ShopValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}