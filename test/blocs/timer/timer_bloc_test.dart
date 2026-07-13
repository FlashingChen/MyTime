import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/blocs/timer/timer_bloc.dart';
import 'package:mytime/blocs/timer/timer_event.dart';
import 'package:mytime/blocs/timer/timer_state.dart';
import 'package:mytime/data/repositories/active_timer_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ActiveTimerRepository activeTimerRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    activeTimerRepo = ActiveTimerRepository();
  });

  group('TimerBloc', () {
    test(
      'starts and accepts ticks before a delayed persistence write finishes',
      () async {
        final store = _ControlledActiveTimerRepository();
        final bloc = TimerBloc(store);
        addTearDown(bloc.close);

        bloc.add(TimerStarted());
        await _settleEvents();

        expect(bloc.state, isA<TimerRunInProgress>());
        bloc.add(const TimerTicked(Duration(seconds: 1)));
        await _settleEvents();

        expect(
          bloc.state,
          isA<TimerRunInProgress>().having(
            (state) => state.duration,
            'duration',
            const Duration(seconds: 1),
          ),
        );

        store.completePendingSave();
      },
    );

    test(
      'keeps the manual start when a pending restore returns later',
      () async {
        final store = _ControlledActiveTimerRepository();
        final bloc = TimerBloc(store);
        addTearDown(bloc.close);

        bloc.add(RestoreTimer());
        await _settleEvents();
        bloc.add(TimerStarted());
        await _settleEvents();
        final manuallyStartedAt = (bloc.state as TimerRunInProgress).startTime;

        store.completePendingRead(DateTime(2026, 7, 11, 9));
        await _settleEvents();

        expect((bloc.state as TimerRunInProgress).startTime, manuallyStartedAt);
        store.completePendingSave();
      },
    );

    test('continues timing when persistence fails', () async {
      final bloc = TimerBloc(_FailingActiveTimerRepository());
      addTearDown(bloc.close);

      bloc.add(TimerStarted());
      await _settleEvents();
      bloc.add(const TimerTicked(Duration(seconds: 1)));
      await _settleEvents();

      expect(
        bloc.state,
        isA<TimerRunInProgress>().having(
          (state) => state.duration,
          'duration',
          const Duration(seconds: 1),
        ),
      );
    });

    test(
      'exposes a recoverable error when a timer session cannot persist',
      () async {
        final bloc = TimerBloc(_FailingActiveTimerRepository());
        addTearDown(bloc.close);

        bloc.add(TimerStarted());
        await _settleEvents();
        await _settleEvents();

        expect(
          bloc.state,
          isA<TimerRunInProgress>().having(
            (state) => state.persistenceError,
            'persistence error',
            isNotNull,
          ),
        );
      },
    );

    blocTest<TimerBloc, TimerState>(
      'emits TimerRunInProgress when TimerStarted is added',
      build: () => TimerBloc(activeTimerRepo),
      act: (bloc) => bloc.add(TimerStarted()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<TimerRunInProgress>().having(
          (s) => s.startTime,
          'startTime',
          isA<DateTime>(),
        ),
      ],
    );

    blocTest<TimerBloc, TimerState>(
      'emits TimerRunComplete when TimerStopped is added during run',
      build: () => TimerBloc(activeTimerRepo),
      seed: () => TimerRunInProgress(
        DateTime.now().subtract(const Duration(seconds: 5)),
        const Duration(seconds: 5),
      ),
      act: (bloc) => bloc.add(TimerStopped()),
      expect: () => [
        isA<TimerRunComplete>().having(
          (s) => s.duration.inSeconds,
          'duration',
          5,
        ),
      ],
    );

    blocTest<TimerBloc, TimerState>(
      'calculates elapsed time from start when stopped before the next tick',
      build: () => TimerBloc(activeTimerRepo),
      seed: () => TimerRunInProgress(
        DateTime.now().subtract(const Duration(seconds: 1)),
        Duration.zero,
      ),
      act: (bloc) => bloc.add(TimerStopped()),
      expect: () => [
        isA<TimerRunComplete>().having(
          (state) => state.duration.inSeconds,
          'duration',
          greaterThanOrEqualTo(1),
        ),
      ],
    );

    blocTest<TimerBloc, TimerState>(
      'emits TimerInitial when TimerReset is added',
      build: () => TimerBloc(activeTimerRepo),
      seed: () => TimerRunInProgress(
        DateTime.now().subtract(const Duration(seconds: 5)),
        const Duration(seconds: 5),
      ),
      act: (bloc) => bloc.add(TimerReset()),
      expect: () => [const TimerInitial()],
    );

    blocTest<TimerBloc, TimerState>(
      'TimerStarted persists start time to ActiveTimerRepository',
      build: () => TimerBloc(activeTimerRepo),
      act: (bloc) => bloc.add(TimerStarted()),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) async {
        final saved = await activeTimerRepo.getStartTime();
        expect(saved, isNotNull);
      },
    );

    blocTest<TimerBloc, TimerState>(
      'TimerStopped persists a session awaiting confirmation',
      build: () => TimerBloc(activeTimerRepo),
      seed: () => TimerRunInProgress(
        DateTime.now().subtract(const Duration(seconds: 5)),
        const Duration(seconds: 5),
      ),
      act: (bloc) => bloc.add(TimerStopped()),
      verify: (bloc) async {
        final saved = await activeTimerRepo.getSession();
        expect(saved, isNotNull);
        expect(saved!.isPendingConfirmation, isTrue);
      },
    );

    blocTest<TimerBloc, TimerState>(
      'TimerReset clears persisted start time',
      build: () => TimerBloc(activeTimerRepo),
      seed: () => TimerRunInProgress(
        DateTime.now().subtract(const Duration(seconds: 5)),
        const Duration(seconds: 5),
      ),
      act: (bloc) => bloc.add(TimerReset()),
      verify: (bloc) async {
        final saved = await activeTimerRepo.getStartTime();
        expect(saved, isNull);
      },
    );

    blocTest<TimerBloc, TimerState>(
      'RestoreTimer emits TimerRunInProgress when persisted start time exists',
      build: () => TimerBloc(activeTimerRepo),
      setUp: () async {
        await activeTimerRepo.saveStartTime(
          DateTime.now().subtract(const Duration(minutes: 10)),
        );
      },
      act: (bloc) => bloc.add(RestoreTimer()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<TimerRunInProgress>().having(
          (s) => s.duration.inMinutes,
          'elapsed minutes',
          greaterThanOrEqualTo(10),
        ),
      ],
    );

    blocTest<TimerBloc, TimerState>(
      'RestoreTimer emits nothing when no persisted start time exists',
      build: () => TimerBloc(activeTimerRepo),
      act: (bloc) => bloc.add(RestoreTimer()),
      wait: const Duration(milliseconds: 50),
      expect: () => [],
    );
  });
}

Future<void> _settleEvents() => Future<void>.delayed(Duration.zero);

class _ControlledActiveTimerRepository extends ActiveTimerRepository {
  final Completer<void> _saveCompleter = Completer<void>();
  final Completer<PersistedTimerSession?> _readCompleter =
      Completer<PersistedTimerSession?>();

  @override
  Future<void> saveSession(PersistedTimerSession session) =>
      _saveCompleter.future;

  @override
  Future<PersistedTimerSession?> getSession() => _readCompleter.future;

  void completePendingSave() {
    if (!_saveCompleter.isCompleted) {
      _saveCompleter.complete();
    }
  }

  void completePendingRead(DateTime? startTime) {
    if (!_readCompleter.isCompleted) {
      _readCompleter.complete(
        startTime == null ? null : PersistedTimerSession(startTime: startTime),
      );
    }
  }
}

class _FailingActiveTimerRepository extends ActiveTimerRepository {
  @override
  Future<void> saveSession(PersistedTimerSession session) {
    throw StateError('Storage unavailable');
  }
}
