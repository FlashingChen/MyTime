import 'package:uuid/uuid.dart';
import 'package:mytime/core/constants/default_categories.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/providers/hive_data_stores.dart';

/// Repository for category persistence using Hive.
abstract interface class CategoriesRepository {
  List<Category> getAll();
  Category? getById(String id);
  Future<Category> add(Category category);
  Future<void> update(Category category);
  Future<void> delete(String id);
}

/// Extends [CategoriesRepository] with complete-dataset replacement for imports.
abstract interface class CategoriesSnapshotRepository
    implements CategoriesRepository {
  Future<void> replaceAll(Iterable<Category> categories);
}

/// DataStore-backed implementation of [CategoriesSnapshotRepository].
class CategoryRepository implements CategoriesSnapshotRepository {
  final CategoryDataStore _store;
  final Uuid _uuid = const Uuid();
  bool _seeded = false;

  CategoryRepository.withStore(this._store);

  @override
  List<Category> getAll() {
    if (!_seeded && _store.isEmpty) {
      for (final category in DefaultCategories.all) {
        _store.put(category.id, category);
      }
      _seeded = true;
    }
    return _store.values.toList();
  }

  @override
  Category? getById(String id) {
    return _store.get(id);
  }

  @override
  Future<Category> add(Category category) async {
    _validate(category);
    final newCategory = Category(
      id: category.id.isEmpty ? _uuid.v4() : category.id,
      name: category.name.trim(),
      color: category.color,
    );
    await _store.put(newCategory.id, newCategory);
    return newCategory;
  }

  @override
  Future<void> update(Category category) async {
    _validate(category);
    await _store.put(category.id, category);
  }

  @override
  Future<void> delete(String id) async {
    await _store.delete(id);
  }

  /// Replaces all categories, used only after a complete import was validated.
  @override
  Future<void> replaceAll(Iterable<Category> categories) async {
    final values = <String, Category>{};
    for (final category in categories) {
      _validate(category);
      if (category.id.isEmpty) {
        throw ArgumentError.value(category.id, 'id', 'must not be blank');
      }
      values[category.id] = Category(
        id: category.id,
        name: category.name.trim(),
        color: category.color,
      );
    }
    await _store.clear();
    if (values.isNotEmpty) await _store.putAll(values);
  }

  void _validate(Category category) {
    if (category.name.trim().isEmpty) {
      throw ArgumentError.value(category.name, 'name', 'must not be blank');
    }
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(category.color)) {
      throw ArgumentError.value(
        category.color,
        'color',
        'must be a #RRGGBB color',
      );
    }
  }
}
