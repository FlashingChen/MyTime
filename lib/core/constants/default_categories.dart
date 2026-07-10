import 'package:mytime/data/models/category.dart';

/// Predefined categories that ship with the app as initial data.
class DefaultCategories {
  DefaultCategories._();

  static List<Category> get all => [
    Category(id: 'work', name: '工作', color: '#6366F1'),
    Category(id: 'read', name: '阅读', color: '#8B5CF6'),
    Category(id: 'sport', name: '运动', color: '#10B981'),
    Category(id: 'study', name: '学习', color: '#F59E0B'),
    Category(id: 'social', name: '社交', color: '#EC4899'),
    Category(id: 'rest', name: '休息', color: '#6B7280'),
    Category(id: 'create', name: '创作', color: '#3B82F6'),
    Category(id: 'other', name: '其他', color: '#9CA3AF'),
  ];

  static Category byId(String id) {
    return all.firstWhere((c) => c.id == id, orElse: () => all.last);
  }
}
