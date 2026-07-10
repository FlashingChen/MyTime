import 'package:equatable/equatable.dart';
import 'package:mytime/data/models/category.dart';

/// States for [CategoriesBloc].
abstract class CategoriesState extends Equatable {
  const CategoriesState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any load.
class CategoriesInitial extends CategoriesState {
  const CategoriesInitial();
}

/// Loading categories.
class CategoriesLoading extends CategoriesState {
  const CategoriesLoading();
}

/// Categories loaded successfully.
class CategoriesLoaded extends CategoriesState {
  final List<Category> categories;

  const CategoriesLoaded(this.categories);

  @override
  List<Object?> get props => [categories];
}

/// Error loading categories.
class CategoriesError extends CategoriesState {
  final String message;

  const CategoriesError(this.message);

  @override
  List<Object?> get props => [message];
}
