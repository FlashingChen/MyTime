import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/records/records_event.dart';
import 'package:mytime/blocs/records/records_state.dart';
import 'package:mytime/data/repositories/record_repository.dart';

/// BLoC that manages time records CRUD operations.
class RecordsBloc extends Bloc<RecordsEvent, RecordsState> {
  final RecordsRepository _repository;
  late final StreamSubscription<void> _changesSubscription;
  bool _ignoreNextRepositoryChange = false;

  RecordsBloc(this._repository) : super(const RecordsInitial()) {
    on<LoadRecords>(_onLoaded);
    on<RecordAdded>(_onAdded);
    on<RecordDeleted>(_onDeleted);
    on<RecordUpdated>(_onUpdated);
    on<LoadRecordsByDate>(_onLoadedByDate);
    _changesSubscription = _repository.changes.listen((_) {
      if (_ignoreNextRepositoryChange) {
        _ignoreNextRepositoryChange = false;
        return;
      }
      add(LoadRecords());
    });
  }

  Future<void> _onUpdated(
    RecordUpdated event,
    Emitter<RecordsState> emit,
  ) async {
    try {
      _ignoreNextRepositoryChange = true;
      await _repository.update(event.record);
      emit(RecordsLoaded(_repository.getAll()));
    } catch (e) {
      _ignoreNextRepositoryChange = false;
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
      _ignoreNextRepositoryChange = true;
      await _repository.add(event.record);
      final records = _repository.getAll();
      emit(RecordsLoaded(records));
    } catch (e) {
      _ignoreNextRepositoryChange = false;
      emit(RecordsError(e.toString()));
    }
  }

  Future<void> _onDeleted(
    RecordDeleted event,
    Emitter<RecordsState> emit,
  ) async {
    try {
      _ignoreNextRepositoryChange = true;
      await _repository.delete(event.id);
      final records = _repository.getAll();
      emit(RecordsLoaded(records));
    } catch (e) {
      _ignoreNextRepositoryChange = false;
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
