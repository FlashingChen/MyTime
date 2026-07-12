import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'time_record.g.dart';

/// A single time tracking record representing one start-to-stop session.
@HiveType(typeId: 0)
// ignore: must_be_immutable
class TimeRecord extends HiveObject with Equatable {
  static const Object _unset = Object();

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

  TimeRecord({
    required this.id,
    this.categoryId,
    required this.startTime,
    required this.endTime,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Duration get duration => endTime.difference(startTime);

  TimeRecord copyWith({
    String? id,
    Object? categoryId = _unset,
    DateTime? startTime,
    DateTime? endTime,
    Object? note = _unset,
    DateTime? createdAt,
  }) {
    return TimeRecord(
      id: id ?? this.id,
      categoryId: identical(categoryId, _unset)
          ? this.categoryId
          : categoryId as String?,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      note: identical(note, _unset) ? this.note : note as String?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, categoryId, startTime, endTime, note];
}
