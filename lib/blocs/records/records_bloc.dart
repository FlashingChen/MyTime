import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/records/records_event.dart';
import 'package:mytime/blocs/records/records_state.dart';
import 'package:mytime/data/repositories/record_repository.dart';

/// BLoC that manages time records CRUD operations.
class RecordsBloc extends Bloc<RecordsEvent, RecordsState> {
  final RecordRepository _repository;

  RecordsBloc(this._repository) : super(const RecordsInitial()) {
    on<RecordsLoaded>(_onLoaded);
    on<RecordAdded>(_onAdded);
    on<RecordDeleted>(_onDeleted);
    on<RecordsLoadedByDate>(_onLoadedByDate);
  }

  Future<void> _onLoaded(RecordsLoaded event, Emitter<RecordsState> emit) async {
    emit(const RecordsLoading());
    try {
      final records = _repository.getAll();
      emit(RecordsLoadSuccess(records));
    } catch (e) {
      emit(RecordsError(e.toString()));
    }
  }

  Future<void> _onAdded(RecordAdded event, Emitter<RecordsState> emit) async {
    try {
      await _repository.add(event.record);
      final records = _repository.getAll();
      emit(RecordsLoadSuccess(records));
    } catch (e) {
      emit(RecordsError(e.toString()));
    }
  }

  Future<void> _onDeleted(RecordDeleted event, Emitter<RecordsState> emit) async {
    try {
      await _repository.delete(event.id);
      final records = _repository.getAll();
      emit(RecordsLoadSuccess(records));
    } catch (e) {
      emit(RecordsError(e.toString()));
    }
  }

  Future<void> _onLoadedByDate(RecordsLoadedByDate event, Emitter<RecordsState> emit) async {
    emit(const RecordsLoading());
    try {
      final records = _repository.getByDate(event.date);
      emit(RecordsLoadSuccess(records));
    } catch (e) {
      emit(RecordsError(e.toString()));
    }
  }
}