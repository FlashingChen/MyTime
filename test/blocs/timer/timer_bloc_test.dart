import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/blocs/timer/timer_bloc.dart';
import 'package:mytime/blocs/timer/timer_event.dart';
import 'package:mytime/blocs/timer/timer_state.dart';
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/data/repositories/active_timer_repository.dart';
import 'package:mytime/data/services/timer_reminder_scheduler.dart';
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

    test('clamps small clock rollbacks to zero while running', () async {
      final bloc = TimerBloc(_ControlledActiveTimerRepository());
      addTearDown(bloc.close);

      bloc.add(TimerStarted());
      await _settleEvents();
      bloc.add(const TimerTicked(Duration(seconds: -1)));
      await _settleEvents();

      expect(
        bloc.state,
        isA<TimerRunInProgress>().having(
          (state) => state.duration,
          'duration',
          Duration.zero,
        ),
      );

      // The session keeps running after a bounded rollback.
      bloc.add(const TimerTicked(Duration(seconds: 2)));
      await _settleEvents();
      expect(
        bloc.state,
        isA<TimerRunInProgress>().having(
          (state) => state.duration,
          'duration',
          const Duration(seconds: 2),
        ),
      );
    });

    test(
      'aborts the session when the clock rolls back beyond tolerance',
      () async {
        final scheduler = _SpyReminderScheduler();
        final bloc = TimerBloc(
          _ControlledActiveTimerRepository(),
          reminderScheduler: scheduler,
        );
        addTearDown(bloc.close);

        bloc.add(TimerStarted());
        await _settleEvents();
        bloc.add(const TimerTicked(Duration(minutes: -6)));
        await _settleEvents();

        expect(
          bloc.state,
          isA<TimerInitial>().having(
            (state) => state.error,
            'error',
            '检测到系统时间异常，本次计时已重置。',
          ),
        );
        expect(scheduler.cancelCount, 1);

        // A late tick must not revive the aborted session.
        bloc.add(const TimerTicked(Duration(seconds: 1)));
        await _settleEvents();
        expect(bloc.state, isA<TimerInitial>());
      },
    );

    test(
      'RestoreTimer aborts when the persisted start is far in the future',
      () async {
        final store = _ControlledActiveTimerRepository();
        final bloc = TimerBloc(store);
        addTearDown(bloc.close);

        bloc.add(RestoreTimer());
        await _settleEvents();
        store.completePendingRead(
          DateTime.now().add(const Duration(minutes: 10)),
        );
        await _settleEvents();

        expect(
          bloc.state,
          isA<TimerInitial>().having(
            (state) => state.error,
            'error',
            isNotNull,
          ),
        );
      },
    );

    test('RestoreTimer clamps a small clock rollback to zero', () async {
      final store = _ControlledActiveTimerRepository();
      final bloc = TimerBloc(store);
      addTearDown(bloc.close);

      bloc.add(RestoreTimer());
      await _settleEvents();
      store.completePendingRead(DateTime.now().add(const Duration(seconds: 1)));
      await _settleEvents();

      expect(
        bloc.state,
        isA<TimerRunInProgress>().having(
          (state) => state.duration,
          'duration',
          Duration.zero,
        ),
      );
    });

    blocTest<TimerBloc, TimerState>(
      'aborts a rolled-back clock when stopped',
      build: () => TimerBloc(activeTimerRepo),
      seed: () => TimerRunInProgress(
        DateTime.now().add(const Duration(seconds: 5)),
        Duration.zero,
      ),
      setUp: () async {
        await activeTimerRepo.saveSession(
          PersistedTimerSession(
            startTime: DateTime.now().add(const Duration(seconds: 5)),
          ),
        );
      },
      act: (bloc) => bloc.add(TimerStopped()),
      expect: () => [
        isA<TimerInitial>().having(
          (state) => state.error,
          'error',
          '检测到系统时间异常，本次计时已重置。',
        ),
      ],
      verify: (bloc) async {
        // The unsaveable session must not survive into the next launch.
        expect(await activeTimerRepo.getSession(), isNull);
      },
    );

    blocTest<TimerBloc, TimerState>(
      'RestoreTimer aborts a negative pending-confirmation session',
      build: () => TimerBloc(activeTimerRepo),
      setUp: () async {
        await activeTimerRepo.saveSession(
          PersistedTimerSession(
            startTime: DateTime(2026, 7, 11, 10),
            stoppedAt: DateTime(2026, 7, 11, 9, 55),
          ),
        );
      },
      act: (bloc) => bloc.add(RestoreTimer()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<TimerInitial>().having(
          (state) => state.error,
          'error',
          '检测到系统时间异常，本次计时已重置。',
        ),
      ],
    );

    blocTest<TimerBloc, TimerState>(
      'keeps the existing initial error when persistence fails again',
      build: () => TimerBloc(activeTimerRepo),
      seed: () => const TimerInitial(error: '检测到系统时间异常，本次计时已重置。'),
      act: (bloc) =>
          bloc.add(const TimerPersistenceFailed('计时会话未能清除；下次启动可能需要再次确认。')),
      expect: () => [
        const TimerInitial(
          error:
              '检测到系统时间异常，本次计时已重置。\n'
              '计时会话未能清除；下次启动可能需要再次确认。',
        ),
      ],
    );

    blocTest<TimerBloc, TimerState>(
      'RestoreTimer aborts a zero-duration pending-confirmation session',
      build: () => TimerBloc(activeTimerRepo),
      setUp: () async {
        await activeTimerRepo.saveSession(
          PersistedTimerSession(
            startTime: DateTime(2026, 7, 11, 10),
            stoppedAt: DateTime(2026, 7, 11, 10),
          ),
        );
      },
      act: (bloc) => bloc.add(RestoreTimer()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<TimerInitial>().having(
          (state) => state.error,
          'error',
          '检测到系统时间异常，本次计时已重置。',
        ),
      ],
    );

    group('reminder scheduling', () {
      test(
        'TimerStarted syncs the reminder scheduler with the new start',
        () async {
          final scheduler = _SpyReminderScheduler();
          final bloc = TimerBloc(
            _ControlledActiveTimerRepository(),
            reminderScheduler: scheduler,
          );
          addTearDown(bloc.close);

          bloc.add(TimerStarted());
          await _settleEvents();

          expect(scheduler.syncCount, 1);
          expect(scheduler.lastStartTime, isNotNull);
          expect(scheduler.cancelCount, 0);
        },
      );

      test('TimerTicked advances the scheduler while running', () async {
        final scheduler = _SpyReminderScheduler();
        final bloc = TimerBloc(
          _ControlledActiveTimerRepository(),
          reminderScheduler: scheduler,
        );
        addTearDown(bloc.close);

        bloc.add(TimerStarted());
        await _settleEvents();
        bloc.add(const TimerTicked(Duration(minutes: 30)));
        await _settleEvents();

        expect(scheduler.onTickCount, 1);
      });

      test(
        'TimerTicked does not advance the scheduler when not running',
        () async {
          final scheduler = _SpyReminderScheduler();
          final bloc = TimerBloc(
            _ControlledActiveTimerRepository(),
            reminderScheduler: scheduler,
          );
          addTearDown(bloc.close);

          bloc.add(const TimerTicked(Duration(minutes: 30)));
          await _settleEvents();

          expect(scheduler.onTickCount, 0);
        },
      );

      test('TimerStopped cancels reminders', () async {
        final scheduler = _SpyReminderScheduler();
        final bloc = TimerBloc(
          _ControlledActiveTimerRepository(),
          reminderScheduler: scheduler,
        );
        addTearDown(bloc.close);

        bloc.add(TimerStarted());
        await _settleEvents();
        bloc.add(TimerStopped());
        await _settleEvents();

        expect(scheduler.cancelCount, 1);
      });

      test('TimerReset cancels reminders', () async {
        final scheduler = _SpyReminderScheduler();
        final bloc = TimerBloc(
          _ControlledActiveTimerRepository(),
          reminderScheduler: scheduler,
        );
        addTearDown(bloc.close);

        bloc.add(TimerStarted());
        await _settleEvents();
        bloc.add(TimerReset());
        await _settleEvents();

        expect(scheduler.cancelCount, 1);
      });

      test(
        'RestoreTimer syncs reminders for a restored running session',
        () async {
          final store = _ControlledActiveTimerRepository();
          final scheduler = _SpyReminderScheduler();
          final bloc = TimerBloc(store, reminderScheduler: scheduler);
          addTearDown(bloc.close);

          bloc.add(RestoreTimer());
          await _settleEvents();
          expect(scheduler.syncCount, 0); // read still pending

          // A session that began 10 minutes ago is running again.
          store.completePendingRead(
            DateTime.now().subtract(const Duration(minutes: 10)),
          );
          await _settleEvents();

          expect(scheduler.syncCount, 1);
          expect(scheduler.lastStartTime, isNotNull);
          expect(scheduler.cancelCount, 0);
        },
      );
    });
  });
}

Future<void> _settleEvents() => Future<void>.delayed(Duration.zero);

class _SpyReminderScheduler implements ReminderScheduler {
  int syncCount = 0;
  int onTickCount = 0;
  int cancelCount = 0;
  DateTime? lastStartTime;

  @override
  void configure(AppSettings settings) {}

  @override
  void sync(DateTime startTime, DateTime now) {
    syncCount++;
    lastStartTime = startTime;
  }

  @override
  void onTick(DateTime now) {
    onTickCount++;
  }

  @override
  void cancel() {
    cancelCount++;
  }
}

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
