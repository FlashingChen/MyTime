import 'package:equatable/equatable.dart';

/// A category for classifying time records.
class Category extends Equatable {
  final String id;
  final String name;
  final String color;
  final bool isSystem;

  const Category({
    required this.id,
    required this.name,
    required this.color,
    this.isSystem = false,
  });

  Category copyWith({
    String? id,
    String? name,
    String? color,
    bool? isSystem,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  @override
  List<Object?> get props => [id, name, color, isSystem];
}
