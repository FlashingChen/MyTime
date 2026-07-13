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

/// Restores a previously persisted active timer, if any.
///
/// Dispatched on app launch to resume a timer that was running when
/// the app was killed.
class RestoreTimer extends TimerEvent {}

/// Signals that an asynchronous session persistence operation failed.
class TimerPersistenceFailed extends TimerEvent {
  const TimerPersistenceFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
