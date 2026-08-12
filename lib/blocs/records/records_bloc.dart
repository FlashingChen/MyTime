import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/records/records_event.dart';
import 'package:mytime/blocs/records/records_state.dart';
import 'package:mytime/data/repositories/record_repository.dart';

/// BLoC that manages time records CRUD operations.
class RecordsBloc extends Bloc<RecordsEvent, RecordsState> {
  final RecordsRepository _repository;
  late final StreamSubscription<void> _changesSubscription;

  RecordsBloc(this._repository) : super(const RecordsInitial()) {
    on<LoadRecords>(_onLoaded);
    on<RecordAdded>(_onAdded);
    on<RecordDeleted>(_onDeleted);
    on<RecordUpdated>(_onUpdated);
    on<LoadRecordsByDate>(_onLoadedByDate);
    _changesSubscription = _repository.changes.listen((_) => add(LoadRecords()));
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
    // Keep the loading state for the first load; refreshes reload silently so
    // repository-driven reloads after a local write do not flash the UI.
    if (state is! RecordsLoaded) emit(const RecordsLoading());
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

  @override
  Future<void> close() async {
    await _changesSubscription.cancel();
    return super.close();
  }
}
