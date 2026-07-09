import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/core/constants/default_categories.dart';

void main() {
  group('DefaultCategories', () {
    test('has 8 default categories', () {
      expect(DefaultCategories.all.length, 8);
    });

    test('system categories cannot be deleted', () {
      for (final cat in DefaultCategories.all) {
        expect(cat.isSystem, isTrue);
      }
    });

    test('work category has correct color', () {
      final work = DefaultCategories.all.firstWhere((c) => c.id == 'work');
      expect(work.color, '#6366F1');
      expect(work.name, '工作');
    });

    test('byId returns matching category', () {
      final study = DefaultCategories.byId('study');
      expect(study.id, 'study');
      expect(study.name, '学习');
    });

    test('byId returns "other" for unknown id', () {
      final cat = DefaultCategories.byId('nonexistent');
      expect(cat.id, 'other');
    });
  });
}