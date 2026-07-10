import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:mytime/core/constants/default_categories.dart';
import 'package:mytime/data/models/category.dart';

/// Repository for category persistence using Hive.
class CategoryRepository {
  final Box<Category> _box;
  final Uuid _uuid = const Uuid();
  bool _seeded = false;

  CategoryRepository(this._box);

  List<Category> getAll() {
    if (!_seeded && _box.isEmpty) {
      for (final category in DefaultCategories.all) {
        _box.put(category.id, category);
      }
      _seeded = true;
    }
    return _box.values.toList();
  }

  Category? getById(String id) {
    return _box.get(id);
  }

  Future<Category> add(Category category) async {
    final newCategory = Category(
      id: category.id.isEmpty ? _uuid.v4() : category.id,
      name: category.name,
      color: category.color,
    );
    await _box.put(newCategory.id, newCategory);
    return newCategory;
  }

  Future<void> update(Category category) async {
    await _box.put(category.id, category);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
