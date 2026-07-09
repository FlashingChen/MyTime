import 'package:mytime/data/models/category.dart';

/// Predefined system categories that ship with the app.
class DefaultCategories {
  DefaultCategories._();

  static const List<Category> all = [
    Category(id: 'work', name: '工作', color: '#6366F1', isSystem: true),
    Category(id: 'read', name: '阅读', color: '#8B5CF6', isSystem: true),
    Category(id: 'sport', name: '运动', color: '#10B981', isSystem: true),
    Category(id: 'study', name: '学习', color: '#F59E0B', isSystem: true),
    Category(id: 'social', name: '社交', color: '#EC4899', isSystem: true),
    Category(id: 'rest', name: '休息', color: '#6B7280', isSystem: true),
    Category(id: 'create', name: '创作', color: '#3B82F6', isSystem: true),
    Category(id: 'other', name: '其他', color: '#9CA3AF', isSystem: true),
  ];

  static Category byId(String id) {
    return all.firstWhere((c) => c.id == id, orElse: () => all.last);
  }
}