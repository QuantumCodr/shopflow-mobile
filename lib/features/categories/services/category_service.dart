import '../data/category_repository.dart';
import '../models/category.dart';

class CategoryServiceException implements Exception {
  const CategoryServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CategoryService {
  CategoryService({
    CategoryRepository? repository,
  }) : _repository = repository ?? CategoryRepository();

  final CategoryRepository _repository;

  // =========================================================
  // READ
  // =========================================================

  Future<List<ShopCategory>> getCategories() async {
    try {
      final rows = await _repository.getCategories();

      return rows
          .map(ShopCategory.fromMap)
          .toList(growable: false);
    } on CategoryRepositoryException catch (error) {
      throw CategoryServiceException(error.message);
    } on FormatException {
      throw const CategoryServiceException(
        'A category contains an invalid date or value.',
      );
    }
  }

  // =========================================================
  // CREATE OR UPDATE
  // =========================================================

  Future<void> saveCategory({
    String? id,
    required String name,
    String? description,
  }) async {
    final cleanName = name.trim();
    final cleanDescription = description?.trim();

    if (cleanName.isEmpty) {
      throw const CategoryServiceException(
        'Enter a category name.',
      );
    }

    if (cleanName.length > 80) {
      throw const CategoryServiceException(
        'Category names cannot exceed 80 characters.',
      );
    }

    if ((cleanDescription?.length ?? 0) > 500) {
      throw const CategoryServiceException(
        'Descriptions cannot exceed 500 characters.',
      );
    }

    try {
      await _repository.saveCategory(
        id: id,
        name: cleanName,
        description: cleanDescription,
      );
    } on CategoryRepositoryException catch (error) {
      throw CategoryServiceException(error.message);
    }
  }

  // =========================================================
  // ACTIVATE OR DEACTIVATE
  // =========================================================

  Future<void> setCategoryActive({
    required String categoryId,
    required bool isActive,
  }) async {
    try {
      await _repository.setCategoryActive(
        categoryId: categoryId,
        isActive: isActive,
      );
    } on CategoryRepositoryException catch (error) {
      throw CategoryServiceException(error.message);
    }
  }

  // =========================================================
  // PRODUCT ASSIGNMENTS
  // =========================================================

  Future<List<CategoryProductOption>> getProductsForCategory({
    required String categoryId,
  }) async {
    try {
      final rows = await _repository.getProductsForCategory(
        categoryId: categoryId,
      );

      return rows
          .map(CategoryProductOption.fromMap)
          .toList(growable: false);
    } on CategoryRepositoryException catch (error) {
      throw CategoryServiceException(error.message);
    }
  }

  Future<void> setProductAssigned({
    required String categoryId,
    required String productId,
    required bool isAssigned,
  }) async {
    try {
      await _repository.setProductAssigned(
        categoryId: categoryId,
        productId: productId,
        isAssigned: isAssigned,
      );
    } on CategoryRepositoryException catch (error) {
      throw CategoryServiceException(error.message);
    }
  }
}