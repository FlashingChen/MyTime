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
class TimerRunInProgress extends TimerState {
  final Duration duration;
  const TimerRunInProgress(this.duration);
  @override
  List<Object?> get props => [duration];
}

/// Timer has been stopped and is awaiting confirmation.
class TimerRunComplete extends TimerState {
  final Duration duration;
  const TimerRunComplete(this.duration);
  @override
  List<Object?> get props => [duration];
}
