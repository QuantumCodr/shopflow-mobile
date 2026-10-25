import '../data/sales_history_repository.dart';
import '../models/sale_history_models.dart';

class SalesHistoryServiceException implements Exception {
  const SalesHistoryServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SalesHistoryService {
  SalesHistoryService({SalesHistoryRepository? repository})
    : _repository = repository ?? SalesHistoryRepository();

  final SalesHistoryRepository _repository;

  Future<List<SaleHistoryRecord>> getRecentSales() async {
    try {
      final rows = await _repository.getRecentSales();

      return rows.map(SaleHistoryRecord.fromMap).toList(growable: false);
    } on SalesHistoryRepositoryException catch (error) {
      throw SalesHistoryServiceException(error.message);
    } on FormatException {
      throw const SalesHistoryServiceException(
        'A sale record contains an invalid date or value.',
      );
    }
  }

  Future<List<SaleHistoryRecord>> getRecentCompletedSales({
    int limit = 5,
  }) async {
    try {
      final rows = await _repository.getRecentCompletedSales(limit: limit);

      return rows.map(SaleHistoryRecord.fromMap).toList(growable: false);
    } on SalesHistoryRepositoryException catch (error) {
      throw SalesHistoryServiceException(error.message);
    } on FormatException {
      throw const SalesHistoryServiceException(
        'A completed sale contains an invalid date or value.',
      );
    }
  }

  Future<List<SaleHistoryRecord>> getCompletedSalesBetween({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    try {
      final rows = await _repository.getCompletedSalesBetween(
        startInclusive: startInclusive,
        endExclusive: endExclusive,
      );

      return rows.map(SaleHistoryRecord.fromMap).toList(growable: false);
    } on SalesHistoryRepositoryException catch (error) {
      throw SalesHistoryServiceException(error.message);
    } on FormatException {
      throw const SalesHistoryServiceException(
        'A sale record contains an invalid date or value.',
      );
    }
  }

  Future<List<SaleHistoryItem>> getSaleItems({required String saleId}) async {
    try {
      final rows = await _repository.getSaleItems(saleId: saleId);

      return rows.map(SaleHistoryItem.fromMap).toList(growable: false);
    } on SalesHistoryRepositoryException catch (error) {
      throw SalesHistoryServiceException(error.message);
    } on FormatException {
      throw const SalesHistoryServiceException(
        'A sale item contains an invalid value.',
      );
    }
  }
}
