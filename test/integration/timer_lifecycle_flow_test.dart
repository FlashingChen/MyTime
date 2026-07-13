import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mytime/blocs/records/records_bloc.dart';
import 'package:mytime/blocs/records/records_event.dart';
import 'package:mytime/blocs/records/records_state.dart';
import 'package:mytime/blocs/settings/settings_bloc.dart';
import 'package:mytime/blocs/settings/settings_event.dart';
import 'package:mytime/blocs/timer/timer_bloc.dart';
import 'package:mytime/blocs/timer/timer_event.dart';
import 'package:mytime/blocs/timer/timer_state.dart';
import 'package:mytime/data/dtos/hive_time_record.dart';
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/data/providers/hive_data_stores.dart';
import 'package:mytime/data/repositories/active_timer_repository.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/data/repositories/settings_repository.dart';
import 'package:mytime/ui/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late RecordRepository recordsRepository;

  setUpAll(() async {
    final hiveDirectory = await Directory.systemTemp.createTemp(
      'mytime_timer_lifecycle_',
    );
    Hive.init(hiveDirectory.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HiveTimeRecordAdapter());
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final recordsBox = await Hive.openBox<HiveTimeRecord>('lifecycle_records');
    recordsRepository = RecordRepository.withStore(
      HiveRecordDataStore(recordsBox),
    );
  });

  testWidgets(
    'restores a stopped session after app reconstruction and saves it to timeline',
    (tester) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      });
      final firstLaunchTimerStore = ActiveTimerRepository();

      await tester.pumpWidget(
        _buildApp(
          recordsRepository: recordsRepository,
          timerStore: firstLaunchTimerStore,
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('start_timer_button')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('正在计时'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('stop_timer_button')));
      await tester.pumpAndSettle();
      expect(find.text('记录详情'), findsOneWidget);

      final pendingSession = await firstLaunchTimerStore.getSession();
      expect(pendingSession, isNotNull);
      expect(pendingSession!.isPendingConfirmation, isTrue);

      // Replacing the root disposes the first TimerBloc, while the real
      // SharedPreferences-backed session remains available to the next launch.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final relaunchedTimerStore = ActiveTimerRepository();
      late TimerBloc relaunchedTimerBloc;
      late RecordsBloc relaunchedRecordsBloc;
      await tester.pumpWidget(
        _buildApp(
          recordsRepository: recordsRepository,
          timerStore: relaunchedTimerStore,
          onTimerBlocCreated: (bloc) => relaunchedTimerBloc = bloc,
          onRecordsBlocCreated: (bloc) => relaunchedRecordsBloc = bloc,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('记录详情'), findsOneWidget);

      await tester.tap(find.text('确认保存'));
      await _settleFileBackedBlocEvents(tester);

      expect(relaunchedRecordsBloc.state, isA<RecordsLoaded>());
      expect(relaunchedTimerBloc.state, isA<TimerInitial>());
      expect(find.text('记录详情'), findsNothing);

      final savedRecords = recordsRepository.getAll();
      expect(savedRecords, hasLength(1));
      expect(savedRecords.single.startTime, pendingSession.startTime);
      expect(savedRecords.single.endTime, pendingSession.stoppedAt);
      expect(
        recordsRepository.getByDate(savedRecords.single.startTime),
        contains(savedRecords.single),
      );

      await tester.tap(find.text('时间线'));
      await tester.pumpAndSettle();
      expect(find.text('工作'), findsWidgets);
    },
  );
}

Future<void> _settleFileBackedBlocEvents(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

Widget _buildApp({
  required RecordRepository recordsRepository,
  required ActiveTimerStore timerStore,
  ValueChanged<TimerBloc>? onTimerBlocCreated,
  ValueChanged<RecordsBloc>? onRecordsBlocCreated,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) {
          final bloc = TimerBloc(timerStore)..add(RestoreTimer());
          onTimerBlocCreated?.call(bloc);
          return bloc;
        },
      ),
      BlocProvider(
        create: (_) {
          final bloc = RecordsBloc(recordsRepository)..add(LoadRecords());
          onRecordsBlocCreated?.call(bloc);
          return bloc;
        },
      ),
      BlocProvider(
        create: (_) =>
            SettingsBloc(_TestSettingsRepository())..add(const LoadSettings()),
      ),
    ],
    child: const AppShell(),
  );
}

class _TestSettingsRepository extends SettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings(themeMode: 'light');

  @override
  Future<void> save(AppSettings settings) async {}
}
