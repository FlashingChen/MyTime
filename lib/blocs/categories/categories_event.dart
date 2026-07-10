import 'package:equatable/equatable.dart';
import 'package:mytime/data/models/category.dart';

/// Events for [CategoriesBloc].
abstract class CategoriesEvent extends Equatable {
  const CategoriesEvent();

  @override
  List<Object?> get props => [];
}

/// Load all categories.
class LoadCategories extends CategoriesEvent {
  const LoadCategories();
}

/// Add a new category.
class CategoryAdded extends CategoriesEvent {
  final Category category;

  const CategoryAdded(this.category);

  @override
  List<Object?> get props => [category];
}

/// Update an existing category.
class CategoryUpdated extends CategoriesEvent {
  final Category category;

  const CategoryUpdated(this.category);

  @override
  List<Object?> get props => [category];
}

/// Delete a category by id.
class CategoryDeleted extends CategoriesEvent {
  final String id;

  const CategoryDeleted(this.id);

  @override
  List<Object?> get props => [id];
}
