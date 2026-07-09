import 'package:equatable/equatable.dart';
import 'package:mytime/data/models/time_record.dart';

abstract class RecordsState extends Equatable {
  const RecordsState();
  @override
  List<Object?> get props => [];
}

class RecordsInitial extends RecordsState {
  const RecordsInitial();
}

class RecordsLoading extends RecordsState {
  const RecordsLoading();
}

class RecordsLoadSuccess extends RecordsState {
  final List<TimeRecord> records;
  const RecordsLoadSuccess(this.records);
  @override
  List<Object?> get props => [records];
}

class RecordsError extends RecordsState {
  final String message;
  const RecordsError(this.message);
  @override
  List<Object?> get props => [message];
}