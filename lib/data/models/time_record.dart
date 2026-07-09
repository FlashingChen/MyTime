import 'package:equatable/equatable.dart';

/// A single time tracking record representing one start-to-stop session.
class TimeRecord extends Equatable {
  final String id;
  final String categoryId;
  final DateTime startTime;
  final DateTime endTime;
  final String? note;
  final DateTime createdAt;

  TimeRecord({
    required this.id,
    required this.categoryId,
    required this.startTime,
    required this.endTime,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Duration of this record.
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
