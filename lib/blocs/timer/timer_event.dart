import 'package:equatable/equatable.dart';

/// Events for the TimerBloc.
abstract class TimerEvent extends Equatable {
  const TimerEvent();
  @override
  List<Object?> get props => [];
}

/// Starts the timer.
class TimerStarted extends TimerEvent {}

/// Stops the timer.
class TimerStopped extends TimerEvent {}

/// Resets the timer to initial state.
class TimerReset extends TimerEvent {}

/// Ticks the timer (internal).
class TimerTicked extends TimerEvent {
  final Duration duration;
  const TimerTicked(this.duration);
  @override
  List<Object?> get props => [duration];
}
