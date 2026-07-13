import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mytime/blocs/records/records_bloc.dart';
import 'package:mytime/blocs/records/records_event.dart';
import 'package:mytime/blocs/timer/timer_bloc.dart';
import 'package:mytime/blocs/timer/timer_event.dart';
import 'package:mytime/data/dtos/hive_time_record.dart';
import 'package:mytime/data/providers/hive_data_stores.dart';
import 'package:mytime/data/providers/preferences_store.dart';
import 'package:mytime/data/repositories/active_timer_repository.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/ui/pages/home/home_page.dart';
import 'package:mytime/ui/pages/timeline/timeline_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'persists a pending timer through app reconstruction and saves it to timeline',
    (tester) async {
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(HiveTimeRecordAdapter());
      }
      final box = await Hive.openBox<HiveTimeRecord>('e2e_timer_records');
      await box.clear();
      final records = RecordRepository.withStore(HiveRecordDataStore(box));
      final preferences = _PrefixedPreferencesStore(
        SharedPreferencesStore(),
        'e2e_timer_',
      );
      await preferences.clearSession();

      final firstStore = ActiveTimerRepository(preferences: preferences);
      await tester.pumpWidget(_homeApp(records, firstStore));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('start_timer_button')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('stop_timer_button')));
      await tester.pumpAndSettle();
      expect(find.text('记录详情'), findsOneWidget);

      final pending = await firstStore.getSession();
      expect(pending, isNotNull);
      expect(pending!.isPendingConfirmation, isTrue);

      // The next widget tree uses new BLoCs and new repository/store objects,
      // while retaining real device SharedPreferences and Hive data.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      final reloadedStore = ActiveTimerRepository(preferences: preferences);
      await tester.pumpWidget(_homeApp(records, reloadedStore));
      await tester.pumpAndSettle();
      expect(find.text('记录详情'), findsOneWidget);

      await tester.tap(find.text('确认保存'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(records.getAll(), hasLength(1));
      expect(records.getAll().single.endTime, pending.stoppedAt);

      await tester.pumpWidget(_timelineApp(records));
      await tester.pumpAndSettle();
      expect(find.text('工作'), findsWidgets);
    },
  );
}

Widget _homeApp(RecordRepository records, ActiveTimerStore timerStore) {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => TimerBloc(timerStore)..add(RestoreTimer())),
        BlocProvider(create: (_) => RecordsBloc(records)..add(LoadRecords())),
      ],
      child: const HomePage(),
    ),
  );
}

Widget _timelineApp(RecordRepository records) {
  return MaterialApp(
    home: BlocProvider(
      create: (_) => RecordsBloc(records)..add(LoadRecords()),
      child: const TimelinePage(),
    ),
  );
}

class _PrefixedPreferencesStore implements PreferencesStore {
  _PrefixedPreferencesStore(this._delegate, this._prefix);

  final PreferencesStore _delegate;
  final String _prefix;

  @override
  Future<String?> getString(String key) => _delegate.getString('$_prefix$key');

  @override
  Future<void> remove(String key) => _delegate.remove('$_prefix$key');

  @override
  Future<void> setString(String key, String value) =>
      _delegate.setString('$_prefix$key', value);

  Future<void> clearSession() async {
    await remove('active_timer_start_time');
    await remove('active_timer_stopped_at');
  }
}
