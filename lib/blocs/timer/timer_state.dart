import 'package:equatable/equatable.dart';

/// States for the TimerBloc.
abstract class TimerState extends Equatable {
  const TimerState();
  @override
  List<Object?> get props => [];
}

/// Timer has not been started.
class TimerInitial extends TimerState {
  const TimerInitial();
}

/// Timer is currently running.
///
/// Stores the absolute [startTime] so that the elapsed duration can be
/// recomputed correctly even after an app restart. The [duration] field
/// is updated on each tick so that the BLoC emits a distinct state.
class TimerRunInProgress extends TimerState {
  final DateTime startTime;
  final Duration duration;

  const TimerRunInProgress(this.startTime, this.duration);

  @override
  List<Object?> get props => [startTime, duration];
}

/// Timer has been stopped and is awaiting confirmation.
class TimerRunComplete extends TimerState {
  final DateTime startTime;
  final Duration duration;

  const TimerRunComplete(this.startTime, this.duration);

  @override
  List<Object?> get props => [startTime, duration];
}
