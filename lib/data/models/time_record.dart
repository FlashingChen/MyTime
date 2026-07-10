import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'time_record.g.dart';

/// A single time tracking record representing one start-to-stop session.
@HiveType(typeId: 0)
// ignore: must_be_immutable
class TimeRecord extends HiveObject with Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String categoryId;
  @HiveField(2)
  final DateTime startTime;
  @HiveField(3)
  final DateTime endTime;
  @HiveField(4)
  final String? note;
  @HiveField(5)
  final DateTime createdAt;

  TimeRecord({
    required this.id,
    required this.categoryId,
    required this.startTime,
    required this.endTime,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Duration get duration => endTime.difference(startTime);

  TimeRecord copyWith({
    String? id,
    String? categoryId,
    DateTime? startTime,
    DateTime? endTime,
    String? note,
    DateTime? createdAt,
  }) {
    return TimeRecord(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, categoryId, startTime, endTime, note];
}