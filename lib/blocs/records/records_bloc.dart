import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/records/records_event.dart';
import 'package:mytime/blocs/records/records_state.dart';
import 'package:mytime/data/repositories/record_repository.dart';

/// BLoC that manages time records CRUD operations.
class RecordsBloc extends Bloc<RecordsEvent, RecordsState> {
  final RecordRepository _repository;

  RecordsBloc(this._repository) : super(const RecordsInitial()) {
    on<LoadRecords>(_onLoaded);
    on<RecordAdded>(_onAdded);
    on<RecordDeleted>(_onDeleted);
    on<RecordUpdated>(_onUpdated);
    on<LoadRecordsByDate>(_onLoadedByDate);
  }

  Future<void> _onUpdated(
    RecordUpdated event,
    Emitter<RecordsState> emit,
  ) async {
    try {
      await _repository.update(event.record);
      emit(RecordsLoaded(_repository.getAll()));
    } catch (e) {
      emit(RecordsError(e.toString()));
    }
  }

  Future<void> _onLoaded(LoadRecords event, Emitter<RecordsState> emit) async {
    emit(const RecordsLoading());
    try {
      final records = _repository.getAll();
      emit(RecordsLoaded(records));
    } catch (e) {
      emit(RecordsError(e.toString()));
    }
  }

  Future<void> _onAdded(RecordAdded event, Emitter<RecordsState> emit) async {
    try {
      await _repository.add(event.record);
      final records = _repository.getAll();
      emit(RecordsLoaded(records));
    } catch (e) {
      emit(RecordsError(e.toString()));
    }
  }

  Future<void> _onDeleted(
    RecordDeleted event,
    Emitter<RecordsState> emit,
  ) async {
    try {
      await _repository.delete(event.id);
      final records = _repository.getAll();
      emit(RecordsLoaded(records));
    } catch (e) {
      emit(RecordsError(e.toString()));
    }
  }

  Future<void> _onLoadedByDate(
    LoadRecordsByDate event,
    Emitter<RecordsState> emit,
  ) async {
    emit(const RecordsLoading());
    try {
      final records = _repository.getByDate(event.date);
      emit(RecordsLoaded(records));
    } catch (e) {
      emit(RecordsError(e.toString()));
    }
  }
}
