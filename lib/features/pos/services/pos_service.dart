import '../../products/services/product_service.dart';
import '../data/pos_repository.dart';
import '../models/pos_models.dart';

class PosServiceException implements Exception {
  const PosServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PosService {
  PosService({
    ProductService? productService,
    PosRepository? repository,
  })  : _productService = productService ?? ProductService(),
        _repository = repository ?? PosRepository();

  final ProductService _productService;
  final PosRepository _repository;

  /// Combines active products with their recorded stock levels.
  Future<List<PosCatalogItem>> loadCatalog() async {
    final products = await _productService.getActiveProducts();

    if (products.isEmpty) {
      return const [];
    }

    final stockLevels = await _repository.getStockLevels();

    return products.map((product) {
      return PosCatalogItem(
        product: product,
        availableQuantity: stockLevels[product.id] ?? 0,
      );
    }).toList(growable: false);
  }

  /// Validates a cart and submits it for authoritative processing by PostgreSQL.
  Future<PosReceipt> completeSale({
    required List<PosCartLine> lines,
    required int paymentAmount,
  }) async {
    if (lines.isEmpty) {
      throw const PosServiceException(
        'Add at least one product before completing a sale.',
      );
    }

    if (paymentAmount < 0) {
      throw const PosServiceException(
        'The payment amount cannot be negative.',
      );
    }

    final productIds = <String>{};

    for (final line in lines) {
      if (line.quantity <= 0) {
        throw const PosServiceException(
          'Every product must have a quantity greater than zero.',
        );
      }

      if (!productIds.add(line.product.id)) {
        throw const PosServiceException(
          'The cart contains a duplicate product. '
          'Please review the cart and try again.',
        );
      }
    }

    // This is a preliminary client-side check, not the authoritative total.
    final estimatedTotal = lines.fold<int>(
      0,
      (sum, line) => sum + line.lineTotal,
    );

    if (paymentAmount < estimatedTotal) {
      throw const PosServiceException(
        'The amount received is less than the displayed total.',
      );
    }

    final items = lines.map((line) {
      return <String, dynamic>{
        'product_id': line.product.id,
        'quantity': line.quantity,
      };
    }).toList(growable: false);

    final response = await _repository.completeSale(
      items: items,
      paymentAmount: paymentAmount,
    );

    // The receipt is built from the database's response, not from a
    // client-generated sale number or a client-calculated final total.
    return PosReceipt.fromMap(response);
  }
}