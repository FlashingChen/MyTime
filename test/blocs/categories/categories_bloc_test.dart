import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mytime/blocs/categories/categories_bloc.dart';
import 'package:mytime/blocs/categories/categories_event.dart';
import 'package:mytime/blocs/categories/categories_state.dart';
import 'package:mytime/data/dtos/hive_category.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/providers/hive_data_stores.dart';
import 'package:mytime/data/repositories/category_repository.dart';

void main() {
  late CategoryRepository repo;

  setUpAll(() {
    Hive.init('test_hive_categories_bloc');
    if (!Hive.isAdapterRegistered(HiveCategoryAdapter().typeId)) {
      Hive.registerAdapter(HiveCategoryAdapter());
    }
  });

  setUp(() async {
    final box = await Hive.openBox<HiveCategory>('categories_bloc');
    repo = CategoryRepository.withStore(HiveCategoryDataStore(box));
  });

  tearDown(() async {
    await Hive.box<HiveCategory>('categories_bloc').clear();
    await Hive.box<HiveCategory>('categories_bloc').close();
  });

  tearDownAll(() async {
    await Hive.close();
    final dir = Directory('test_hive_categories_bloc');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  group('CategoriesBloc', () {
    blocTest<CategoriesBloc, CategoriesState>(
      'emits CategoriesLoaded on LoadCategories',
      build: () => CategoriesBloc(repo),
      act: (bloc) => bloc.add(const LoadCategories()),
      expect: () => [const CategoriesLoading(), isA<CategoriesLoaded>()],
    );

    blocTest<CategoriesBloc, CategoriesState>(
      'emits CategoriesLoaded with added category',
      build: () => CategoriesBloc(repo),
      act: (bloc) async {
        bloc.add(const LoadCategories());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(
          CategoryAdded(Category(id: '', name: 'New', color: '#000000')),
        );
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const CategoriesLoading(),
        isA<CategoriesLoaded>(),
        isA<CategoriesLoaded>(),
      ],
      verify: (bloc) {
        final state = bloc.state as CategoriesLoaded;
        expect(state.categories.any((c) => c.name == 'New'), isTrue);
      },
    );

    blocTest<CategoriesBloc, CategoriesState>(
      'deletes a default category and clears its records',
      build: () => CategoriesBloc(repo),
      act: (bloc) async {
        bloc.add(const LoadCategories());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const CategoryDeleted('work'));
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const CategoriesLoading(),
        isA<CategoriesLoaded>(),
        isA<CategoriesLoaded>(),
      ],
      verify: (bloc) {
        final state = bloc.state as CategoriesLoaded;
        expect(state.categories.any((c) => c.id == 'work'), isFalse);
      },
    );

    blocTest<CategoriesBloc, CategoriesState>(
      'rejects deletion of the last category',
      build: () => CategoriesBloc(repo),
      setUp: () async {
        final box = repo.getAll().first;
        for (final c in repo.getAll().where((c) => c.id != box.id).toList()) {
          await repo.delete(c.id);
        }
      },
      act: (bloc) async {
        bloc.add(const LoadCategories());
        await Future.delayed(const Duration(milliseconds: 50));
        final last = repo.getAll().single;
        bloc.add(CategoryDeleted(last.id));
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const CategoriesLoading(),
        isA<CategoriesLoaded>(),
        isA<CategoriesError>(),
      ],
    );
  });
}
