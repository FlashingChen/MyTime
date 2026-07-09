import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'category.g.dart';

@HiveType(typeId: 1)
class Category extends HiveObject with EquatableMixin {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String color;
  @HiveField(3)
  final bool isSystem;

  Category({
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