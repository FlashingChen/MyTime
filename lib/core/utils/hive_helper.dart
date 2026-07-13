import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mytime/data/dtos/hive_time_record.dart';
import 'package:mytime/data/dtos/hive_category.dart';

class HiveHelper {
  HiveHelper._();

  static const String recordsBox = 'records';
  static const String categoriesBox = 'categories';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(HiveTimeRecordAdapter());
    Hive.registerAdapter(HiveCategoryAdapter());
  }

  static Future<Box<HiveTimeRecord>> openRecordsBox() async {
    return Hive.openBox<HiveTimeRecord>(recordsBox);
  }

  static Future<Box<HiveCategory>> openCategoriesBox() async {
    return Hive.openBox<HiveCategory>(categoriesBox);
  }
}
