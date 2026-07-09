import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/blocs/timer/timer_bloc.dart';
import 'package:mytime/blocs/timer/timer_event.dart';
import 'package:mytime/blocs/timer/timer_state.dart';

void main() {
  group('TimerBloc', () {
    blocTest<TimerBloc, TimerState>(
      'emits TimerRunInProgress when TimerStarted is added',
      build: () => TimerBloc(),
      act: (bloc) => bloc.add(TimerStarted()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<TimerRunInProgress>(),
      ],
    );

    blocTest<TimerBloc, TimerState>(
      'emits TimerRunComplete when TimerStopped is added during run',
      build: () => TimerBloc(),
      seed: () => const TimerRunInProgress(Duration(seconds: 5)),
      act: (bloc) => bloc.add(TimerStopped()),
      expect: () => [
        isA<TimerRunComplete>(),
      ],
    );

    blocTest<TimerBloc, TimerState>(
      'emits TimerInitial when TimerReset is added',
      build: () => TimerBloc(),
      seed: () => const TimerRunInProgress(Duration(seconds: 5)),
      act: (bloc) => bloc.add(TimerReset()),
      expect: () => [const TimerInitial()],
    );
  });
}
