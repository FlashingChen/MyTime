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
  Timer? _ticker;
  Future<void> _storageQueue = Future<void>.value();
  int _sessionVersion = 0;

  TimerBloc(this._activeTimerStore) : super(const TimerInitial()) {
    on<TimerStarted>(_onStarted);
    on<TimerStopped>(_onStopped);
    on<TimerReset>(_onReset);
    on<TimerTicked>(_onTicked);
    on<RestoreTimer>(_onRestore);
    on<TimerPersistenceFailed>(_onPersistenceFailed);
  }

  void _onStarted(TimerStarted event, Emitter<TimerState> emit) {
    _sessionVersion++;
    _cancelTicker();
    final start = DateTime.now();
    emit(TimerRunInProgress(start, Duration.zero));
    _startTicker(start);
    _enqueueStorage(
      () => _activeTimerStore.saveSession(
        PersistedTimerSession(startTime: start),
      ),
      failureMessage: '计时会话未能保存；退出应用可能丢失本次计时。',
    );
  }

  Future<void> _onRestore(RestoreTimer event, Emitter<TimerState> emit) async {
    final versionAtRequest = _sessionVersion;
    PersistedTimerSession? savedSession;
    try {
      savedSession = await _activeTimerStore.getSession();
    } catch (_) {
      return;
    }
    if (savedSession == null ||
        _sessionVersion != versionAtRequest ||
        state is! TimerInitial) {
      return;
    }
    if (savedSession.isPendingConfirmation) {
      final stoppedAt = savedSession.stoppedAt!;
      emit(
        TimerRunComplete(
          savedSession.startTime,
          stoppedAt.difference(savedSession.startTime),
          stoppedAt,
        ),
      );
      return;
    }
    final elapsed = DateTime.now().difference(savedSession.startTime);
    emit(TimerRunInProgress(savedSession.startTime, elapsed));
    _startTicker(savedSession.startTime);
  }

  void _onStopped(TimerStopped event, Emitter<TimerState> emit) {
    _sessionVersion++;
    _cancelTicker();
    if (state is TimerRunInProgress) {
      final progress = state as TimerRunInProgress;
      final stoppedAt = DateTime.now();
      final elapsed = stoppedAt.difference(progress.startTime);
      emit(TimerRunComplete(progress.startTime, elapsed, stoppedAt));
      _enqueueStorage(
        () => _activeTimerStore.saveSession(
          PersistedTimerSession(
            startTime: progress.startTime,
            stoppedAt: stoppedAt,
          ),
        ),
        failureMessage: '待确认记录未能保存；请在退出前完成或重试。',
      );
    }
  }

  void _onReset(TimerReset event, Emitter<TimerState> emit) {
    _sessionVersion++;
    _cancelTicker();
    emit(const TimerInitial());
    _enqueueStorage(
      _activeTimerStore.clear,
      failureMessage: '计时会话未能清除；下次启动可能需要再次确认。',
    );
  }

  void _onTicked(TimerTicked event, Emitter<TimerState> emit) {
    final current = state;
    if (current is TimerRunInProgress) {
      emit(
        TimerRunInProgress(
          current.startTime,
          event.duration,
          error: current.persistenceError,
        ),
      );
    }
  }

  void _onPersistenceFailed(
    TimerPersistenceFailed event,
    Emitter<TimerState> emit,
  ) {
    final current = state;
    switch (current) {
      case TimerInitial():
        emit(TimerInitial(error: event.message));
      case TimerRunInProgress():
        emit(
          TimerRunInProgress(
            current.startTime,
            current.duration,
            error: event.message,
          ),
        );
      case TimerRunComplete():
        emit(
          TimerRunComplete(
            current.startTime,
            current.duration,
            current.stoppedAt,
            error: event.message,
          ),
        );
    }
  }

  void _startTicker(DateTime start) {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      add(TimerTicked(DateTime.now().difference(start)));
    });
  }

  void _cancelTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _enqueueStorage(
    Future<void> Function() action, {
    required String failureMessage,
  }) {
    _storageQueue = _storageQueue.then(
      (_) => _runStorageAction(action, failureMessage),
      onError: (_, __) => _runStorageAction(action, failureMessage),
    );
  }

  Future<void> _runStorageAction(
    Future<void> Function() action,
    String failureMessage,
  ) async {
    try {
      await action();
    } catch (_) {
      add(TimerPersistenceFailed(failureMessage));
    }
  }

  @override
  Future<void> close() {
    _cancelTicker();
    return super.close();
  }
}
