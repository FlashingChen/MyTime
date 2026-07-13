import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/category.dart';

void main() {
  group('Category', () {
    test('creates with required fields', () {
      final category = Category(id: 'work', name: 'Work', color: '#6366F1');
      expect(category.id, 'work');
      expect(category.name, 'Work');
      expect(category.color, '#6366F1');
    });

    test('equality works via Equatable', () {
      final c1 = Category(id: '1', name: 'Work', color: '#6366F1');
      final c2 = Category(id: '1', name: 'Work', color: '#6366F1');
      expect(c1, equals(c2));
    });

    test('copyWith creates new instance with updated fields', () {
      final category = Category(id: '1', name: 'Work', color: '#6366F1');
      final updated = category.copyWith(name: 'Updated Work');
      expect(updated.id, '1');
      expect(updated.name, 'Updated Work');
      expect(updated.color, '#6366F1');
    });
  });
}
