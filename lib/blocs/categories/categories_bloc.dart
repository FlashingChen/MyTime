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
      if (category == null) throw StateError('分类不存在');
      final all = _repository.getAll();
      if (all.length <= 1) throw StateError('至少保留一个分类');
      await _recordRepository?.clearCategory(event.id);
      await _repository.delete(event.id);
      final categories = _repository.getAll();
      emit(CategoriesLoaded(categories));
    } catch (e) {
      emit(CategoriesError(e.toString()));
    }
  }
}
