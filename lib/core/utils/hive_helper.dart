import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/models/category.dart';

class HiveHelper {
  HiveHelper._();

  static const String recordsBox = 'records';
  static const String categoriesBox = 'categories';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(TimeRecordAdapter());
    Hive.registerAdapter(CategoryAdapter());
  }

  static Future<Box<TimeRecord>> openRecordsBox() async {
    return await Hive.openBox<TimeRecord>(recordsBox);
  }

  static Future<Box<Category>> openCategoriesBox() async {
    return await Hive.openBox<Category>(categoriesBox);
  }
}