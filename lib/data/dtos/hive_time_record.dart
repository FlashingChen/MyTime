import 'package:hive_ce/hive.dart';
import 'package:mytime/data/models/time_record.dart';

part 'hive_time_record.g.dart';

@HiveType(typeId: 0)
class HiveTimeRecord {
  HiveTimeRecord({
    required this.id,
    required this.categoryId,
    required this.startTime,
    required this.endTime,
    required this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  @HiveField(0)
  final String id;
  @HiveField(1)
  final String? categoryId;
  @HiveField(2)
  final DateTime startTime;
  @HiveField(3)
  final DateTime endTime;
  @HiveField(4)
  final String? note;
  @HiveField(5)
  final DateTime createdAt;

  TimeRecord toDomain() => TimeRecord(
    id: id,
    categoryId: categoryId,
    startTime: startTime,
    endTime: endTime,
    note: note,
    createdAt: createdAt,
  );

  factory HiveTimeRecord.fromDomain(TimeRecord record) => HiveTimeRecord(
    id: record.id,
    categoryId: record.categoryId,
    startTime: record.startTime,
    endTime: record.endTime,
    note: record.note,
    createdAt: record.createdAt,
  );
}
