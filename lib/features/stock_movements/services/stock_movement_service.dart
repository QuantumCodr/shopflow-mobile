import '../data/stock_movement_repository.dart';
import '../models/stock_movement_model.dart';

class StockMovementServiceException implements Exception {
  const StockMovementServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StockMovementService {
  StockMovementService({
    StockMovementRepository? repository,
  }) : _repository =
           repository ?? StockMovementRepository();

  final StockMovementRepository _repository;

  Future<List<StockMovement>> getRecentMovements() async {
    try {
      final rows = await _repository.getRecentMovements();

      return rows
          .map(StockMovement.fromMap)
          .toList(growable: false);
    } on StockMovementRepositoryException catch (error) {
      throw StockMovementServiceException(error.message);
    } on FormatException {
      throw const StockMovementServiceException(
        'A stock movement contains an invalid value.',
      );
    }
  }
}