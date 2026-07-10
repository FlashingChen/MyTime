import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'category.g.dart';

@HiveType(typeId: 1)
// ignore: must_be_immutable
class Category extends HiveObject with Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String color;

  Category({
    required this.id,
    required this.name,
    required this.color,
  });

  Category copyWith({
    String? id,
    String? name,
    String? color,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }

  @override
  List<Object?> get props => [id, name, color];
}
