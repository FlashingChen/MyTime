import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/categories/categories_bloc.dart';
import 'package:mytime/blocs/categories/categories_state.dart';
import 'package:mytime/core/constants/default_categories.dart';
import 'package:mytime/data/models/category.dart';

/// Read-only category lookup that prefers the BLoC and falls back to defaults.
class CategoryLookup {
  CategoryLookup._();

  static CategoriesBloc? _tryGetBloc(BuildContext context) {
    try {
      return context.read<CategoriesBloc>();
    } catch (_) {
      return null;
    }
  }

  static List<Category> all(BuildContext context) {
    final bloc = _tryGetBloc(context);
    if (bloc != null && bloc.state is CategoriesLoaded) {
      return (bloc.state as CategoriesLoaded).categories;
    }
    return DefaultCategories.all;
  }

  static Category byId(BuildContext context, String? id) {
    if (id == null) return _uncategorized();
    final allCategories = all(context);
    return allCategories.firstWhere(
      (c) => c.id == id,
      orElse: () => DefaultCategories.byId(id),
    );
  }

  static Category _uncategorized() => Category(
        id: '',
        name: '未分类',
        color: '#9CA3AF',
      );
}
