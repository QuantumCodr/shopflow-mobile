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

  Future<void> adjustStock({
    required String productId,
    required String movementType,
    required String quantityInput,
    required String reason,
    String? referenceId,
  }) async {
    const allowedTypes = {
      'adjustment_in',
      'adjustment_out',
      'damaged',
      'returned',
    };

    if (!allowedTypes.contains(movementType)) {
      throw const InventoryValidationException(
        'Select a valid stock adjustment type.',
      );
    }

    final value = quantityInput.trim();

    if (!RegExp(r'^\d+(?:\.\d{1,3})?$').hasMatch(value)) {
      throw const InventoryValidationException(
        'Enter a valid quantity with up to three decimal places.',
      );
    }

    final quantity = double.tryParse(value);

    if (quantity == null ||
        !quantity.isFinite ||
        quantity <= 0) {
      throw const InventoryValidationException(
        'Quantity must be greater than zero.',
      );
    }

    final cleanReason = reason.trim();

    if (cleanReason.isEmpty) {
      throw const InventoryValidationException(
        'Enter a reason for this adjustment.',
      );
    }

    if (cleanReason.length > 500) {
      throw const InventoryValidationException(
        'The reason cannot exceed 500 characters.',
      );
    }

    await _repository.adjustStock(
      productId: productId,
      movementType: movementType,
      quantity: quantity,
      reason: cleanReason,
      referenceId: referenceId,
    );
  }  
}

class InventoryValidationException implements Exception {
  const InventoryValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}