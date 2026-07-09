import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/timer/timer_event.dart';
import 'package:mytime/blocs/timer/timer_state.dart';

/// BLoC that manages the timer lifecycle.
class TimerBloc extends Bloc<TimerEvent, TimerState> {
  StreamSubscription<Duration>? _tickerSubscription;

  TimerBloc() : super(const TimerInitial()) {
    on<TimerStarted>(_onStarted);
    on<TimerStopped>(_onStopped);
    on<TimerReset>(_onReset);
    on<TimerTicked>(_onTicked);
  }

  Future<void> _onStarted(TimerStarted event, Emitter<TimerState> emit) async {
    emit(const TimerRunInProgress(Duration.zero));
    _tickerSubscription?.cancel();
    final start = DateTime.now();
    _tickerSubscription = Stream.periodic(
      const Duration(milliseconds: 100),
      (_) => DateTime.now().difference(start),
    ).listen((duration) {
      add(TimerTicked(duration));
    });
  }

  void _onStopped(TimerStopped event, Emitter<TimerState> emit) {
    _tickerSubscription?.cancel();
    if (state is TimerRunInProgress) {
      emit(TimerRunComplete((state as TimerRunInProgress).duration));
    }
  }

  void _onReset(TimerReset event, Emitter<TimerState> emit) {
    _tickerSubscription?.cancel();
    emit(const TimerInitial());
  }

  void _onTicked(TimerTicked event, Emitter<TimerState> emit) {
    emit(TimerRunInProgress(event.duration));
  }

  @override
  Future<void> close() {
    _tickerSubscription?.cancel();
    return super.close();
  }
}
