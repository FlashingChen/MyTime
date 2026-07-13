import 'package:equatable/equatable.dart';

/// States for the TimerBloc.
abstract class TimerState extends Equatable {
  const TimerState();

  /// A user-visible warning when the current session was not persisted.
  String? get persistenceError => null;

  @override
  List<Object?> get props => [];
}

/// Timer has not been started.
class TimerInitial extends TimerState {
  const TimerInitial({this.error});

  final String? error;

  @override
  String? get persistenceError => error;

  @override
  List<Object?> get props => [error];
}

/// Timer is currently running.
///
/// Stores the absolute [startTime] so that the elapsed duration can be
/// recomputed correctly even after an app restart. The [duration] field
/// is updated on each tick so that the BLoC emits a distinct state.
class TimerRunInProgress extends TimerState {
  final DateTime startTime;
  final Duration duration;
  final String? error;

  const TimerRunInProgress(this.startTime, this.duration, {this.error});

  @override
  String? get persistenceError => error;

  @override
  List<Object?> get props => [startTime, duration, error];
}

/// Timer has been stopped and is awaiting confirmation.
class TimerRunComplete extends TimerState {
  final DateTime startTime;
  final Duration duration;
  final DateTime stoppedAt;
  final String? error;

  const TimerRunComplete(
    this.startTime,
    this.duration,
    this.stoppedAt, {
    this.error,
  });

  @override
  String? get persistenceError => error;

  @override
  List<Object?> get props => [startTime, duration, stoppedAt, error];
}
