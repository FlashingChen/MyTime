import 'package:equatable/equatable.dart';
import 'package:mytime/data/models/time_record.dart';

abstract class RecordsEvent extends Equatable {
  const RecordsEvent();
  @override
  List<Object?> get props => [];
}

class LoadRecords extends RecordsEvent {}

class RecordAdded extends RecordsEvent {
  final TimeRecord record;
  const RecordAdded(this.record);
  @override
  List<Object?> get props => [record];
}

class RecordDeleted extends RecordsEvent {
  final String id;
  const RecordDeleted(this.id);
  @override
  List<Object?> get props => [id];
}

/// Persist edits to an existing record.
class RecordUpdated extends RecordsEvent {
  final TimeRecord record;
  const RecordUpdated(this.record);
  @override
  List<Object?> get props => [record];
}

class LoadRecordsByDate extends RecordsEvent {
  final DateTime date;
  const LoadRecordsByDate(this.date);
  @override
  List<Object?> get props => [date];
}
