import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mytime/core/constants/default_categories.dart';
import 'package:mytime/data/dtos/hive_category.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/providers/hive_data_stores.dart';
import 'package:mytime/data/repositories/category_repository.dart';

void main() {
  late Box<HiveCategory> box;
  late CategoryRepository repo;

  setUp(() async {
    Hive.init('test_hive_category_repo');
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(HiveCategoryAdapter());
    }
    box = await Hive.openBox<HiveCategory>('test_categories');
    repo = CategoryRepository.withStore(HiveCategoryDataStore(box));
  });

  tearDown(() async {
    await box.clear();
    await box.close();
  });

  tearDownAll(() async {
    await Hive.close();
    final dir = Directory('test_hive_category_repo');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  test('getAll seeds default categories on first load', () {
    final all = repo.getAll();
    expect(all.length, DefaultCategories.all.length);
    expect(
      all.map((c) => c.id).toSet(),
      containsAll(DefaultCategories.all.map((c) => c.id)),
    );
  });

  test('getAll returns persisted categories without reseeding', () async {
    repo.getAll();
    await repo.add(Category(id: '', name: 'Test', color: '#000000'));
    final all = repo.getAll();
    expect(all.length, DefaultCategories.all.length + 1);
  });

  test('add returns category with generated id', () async {
    final category = Category(id: '', name: 'Test', color: '#000000');
    final result = await repo.add(category);
    expect(result.id, isNotEmpty);
    expect(result.name, 'Test');
  });

  test('add persists a Hive DTO that maps back to the category', () async {
    final result = await repo.add(
      Category(id: 'category-id', name: 'Test', color: '#000000'),
    );

    final stored = box.get(result.id);
    expect(stored, isA<HiveCategory>());
    expect(stored?.toDomain(), result);
  });

  test('add rejects a blank name or invalid color', () async {
    await expectLater(
      repo.add(Category(id: '', name: '   ', color: '#000000')),
      throwsArgumentError,
    );
    await expectLater(
      repo.add(Category(id: '', name: 'Test', color: 'black')),
      throwsArgumentError,
    );
  });

  test('update changes category fields', () async {
    await repo.add(Category(id: 'test', name: 'Test', color: '#000000'));
    await repo.update(Category(id: 'test', name: 'Updated', color: '#FFFFFF'));
    final updated = repo.getById('test');
    expect(updated?.name, 'Updated');
    expect(updated?.color, '#FFFFFF');
  });

  test('delete removes category', () async {
    await repo.add(Category(id: 'test', name: 'Test', color: '#000000'));
    await repo.delete('test');
    expect(repo.getById('test'), isNull);
  });
}
