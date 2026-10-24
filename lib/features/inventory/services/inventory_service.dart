import '../data/inventory_repository.dart';
import '../models/inventory_item.dart';

class InventoryService {
  InventoryService({
    InventoryRepository? repository,
  }) : _repository = repository ?? InventoryRepository();

  final InventoryRepository _repository;

  static final RegExp _quantityPattern =
      RegExp(r'^\d+(?:\.\d{1,3})?$');

  Future<List<InventoryItem>> getInventory() {
    return _repository.getInventory();
  }

  Future<void> receiveStock({
    required String productId,
    required String quantityInput,
    String? reason,
  }) async {
    final value = quantityInput.trim();

    if (!_quantityPattern.hasMatch(value)) {
      throw InventoryValidationException(
        'Enter a valid quantity with up to three decimal places.',
      );
    }

    final quantity = double.tryParse(value);

    if (quantity == null ||
        !quantity.isFinite ||
        quantity <= 0) {
      throw InventoryValidationException(
        'Quantity must be greater than zero.',
      );
    }

    if (reason != null && reason.trim().length > 500) {
      throw InventoryValidationException(
        'The reason cannot exceed 500 characters.',
      );
    }

    await _repository.receiveStock(
      productId: productId,
      quantity: quantity,
      reason: reason?.trim().isEmpty ?? true
          ? null
          : reason!.trim(),
    );
  }
}

class InventoryValidationException implements Exception {
  const InventoryValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}