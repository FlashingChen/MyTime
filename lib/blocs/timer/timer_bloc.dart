import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/timer/timer_event.dart';
import 'package:mytime/blocs/timer/timer_state.dart';
import 'package:mytime/data/repositories/active_timer_repository.dart';

/// BLoC that manages the timer lifecycle.
///
/// The timer's start timestamp is persisted via [ActiveTimerRepository] so
/// that a running timer survives app kills and can be restored on next launch.
class TimerBloc extends Bloc<TimerEvent, TimerState> {
  final ActiveTimerStore _activeTimerStore;
  StreamSubscription<Duration>? _tickerSubscription;
  Future<void> _storageQueue = Future<void>.value();
  int _sessionVersion = 0;

  TimerBloc(this._activeTimerStore) : super(const TimerInitial()) {
    on<TimerStarted>(_onStarted);
    on<TimerStopped>(_onStopped);
    on<TimerReset>(_onReset);
    on<TimerTicked>(_onTicked);
    on<RestoreTimer>(_onRestore);
  }

  void _onStarted(TimerStarted event, Emitter<TimerState> emit) {
    _sessionVersion++;
    _tickerSubscription?.cancel();
    final start = DateTime.now();
    emit(TimerRunInProgress(start, Duration.zero));
    _startTicker(start);
    _enqueueStorage(() => _activeTimerStore.saveStartTime(start));
  }

  Future<void> _onRestore(RestoreTimer event, Emitter<TimerState> emit) async {
    final versionAtRequest = _sessionVersion;
    DateTime? savedStart;
    try {
      savedStart = await _activeTimerStore.getStartTime();
    } catch (_) {
      return;
    }
    if (savedStart == null ||
        _sessionVersion != versionAtRequest ||
        state is! TimerInitial) {
      return;
    }
    final elapsed = DateTime.now().difference(savedStart);
    emit(TimerRunInProgress(savedStart, elapsed));
    _startTicker(savedStart);
  }

  void _onStopped(TimerStopped event, Emitter<TimerState> emit) {
    _sessionVersion++;
    _tickerSubscription?.cancel();
    if (state is TimerRunInProgress) {
      final progress = state as TimerRunInProgress;
      final elapsed = DateTime.now().difference(progress.startTime);
      emit(TimerRunComplete(progress.startTime, elapsed));
      _enqueueStorage(_activeTimerStore.clear);
    }
  }

  void _onReset(TimerReset event, Emitter<TimerState> emit) {
    _sessionVersion++;
    _tickerSubscription?.cancel();
    emit(const TimerInitial());
    _enqueueStorage(_activeTimerStore.clear);
  }

  void _onTicked(TimerTicked event, Emitter<TimerState> emit) {
    final current = state;
    if (current is TimerRunInProgress) {
      emit(TimerRunInProgress(current.startTime, event.duration));
    }
  }

  void _startTicker(DateTime start) {
    _tickerSubscription =
        Stream.periodic(
          const Duration(milliseconds: 100),
          (_) => DateTime.now().difference(start),
        ).listen((duration) {
          add(TimerTicked(duration));
        });
  }

  void _enqueueStorage(Future<void> Function() action) {
    _storageQueue = _storageQueue.then((_) => _runStorageAction(action));
  }

  Future<void> _runStorageAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Persistence failure must never interrupt foreground timing.
    }
  }

  @override
  Future<void> close() {
    _tickerSubscription?.cancel();
    return super.close();
  }
}
