import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/categories/categories_event.dart';
import 'package:mytime/blocs/categories/categories_state.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/data/repositories/record_repository.dart';

/// BLoC for managing categories.
class CategoriesBloc extends Bloc<CategoriesEvent, CategoriesState> {
  final CategoryRepository _repository;
  final RecordRepository? _recordRepository;

  CategoriesBloc(this._repository, [this._recordRepository])
    : super(const CategoriesInitial()) {
    on<LoadCategories>(_onLoad);
    on<CategoryAdded>(_onAdded);
    on<CategoryUpdated>(_onUpdated);
    on<CategoryDeleted>(_onDeleted);
  }

  Future<void> _onLoad(
    LoadCategories event,
    Emitter<CategoriesState> emit,
  ) async {
    emit(const CategoriesLoading());
    try {
      final categories = _repository.getAll();
      emit(CategoriesLoaded(categories));
    } catch (e) {
      emit(CategoriesError(e.toString()));
    }
  }

  Future<void> _onAdded(
    CategoryAdded event,
    Emitter<CategoriesState> emit,
  ) async {
    try {
      await _repository.add(event.category);
      final categories = _repository.getAll();
      emit(CategoriesLoaded(categories));
    } catch (e) {
      emit(CategoriesError(e.toString()));
    }
  }

  Future<void> _onUpdated(
    CategoryUpdated event,
    Emitter<CategoriesState> emit,
  ) async {
    try {
      await _repository.update(event.category);
      final categories = _repository.getAll();
      emit(CategoriesLoaded(categories));
    } catch (e) {
      emit(CategoriesError(e.toString()));
    }
  }

  Future<void> _onDeleted(
    CategoryDeleted event,
    Emitter<CategoriesState> emit,
  ) async {
    try {
      final category = _repository.getById(event.id);
      if (category == null || category.isSystem) throw StateError('系统分类不可删除');
      final replacement = event.replacementCategoryId;
      if (replacement != null && _recordRepository != null) {
        await _recordRepository.reassignCategory(event.id, replacement);
      }
      await _repository.delete(event.id);
      final categories = _repository.getAll();
      emit(CategoriesLoaded(categories));
    } catch (e) {
      emit(CategoriesError(e.toString()));
    }
  }
}
