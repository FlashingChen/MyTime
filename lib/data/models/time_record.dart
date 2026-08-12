import 'package:equatable/equatable.dart';

/// A single time tracking record representing one start-to-stop session.
class TimeRecord extends Equatable {
  static const Object _unset = Object();

  final String id;
  final String? categoryId;
  final DateTime startTime;
  final DateTime endTime;
  final String? note;
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
  List<Object?> get props => [
    id,
    categoryId,
    startTime,
    endTime,
    note,
    createdAt,
  ];
}
