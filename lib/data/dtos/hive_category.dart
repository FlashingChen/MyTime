import 'package:hive_ce/hive.dart';
import 'package:mytime/data/models/category.dart';

part 'hive_category.g.dart';

@HiveType(typeId: 1)
class HiveCategory {
  HiveCategory({required this.id, required this.name, required this.color});

  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String color;

  Category toDomain() => Category(id: id, name: name, color: color);

  factory HiveCategory.fromDomain(Category category) =>
      HiveCategory(id: category.id, name: category.name, color: category.color);
}
