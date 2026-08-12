import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mytime/blocs/records/records_bloc.dart';
import 'package:mytime/blocs/records/records_event.dart';
import 'package:mytime/blocs/records/records_state.dart';
import 'package:mytime/data/dtos/hive_time_record.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/providers/hive_data_stores.dart';
import 'package:mytime/data/repositories/record_repository.dart';

void main() {
  late RecordRepository repo;

  setUpAll(() async {
    Hive.init('test_hive_records_bloc');
    Hive.registerAdapter(HiveTimeRecordAdapter());
  });

  setUp(() async {
    final box = await Hive.openBox<HiveTimeRecord>('records');
    repo = RecordRepository.withStore(HiveRecordDataStore(box));
  });

  tearDown(() async {
    await Hive.box<HiveTimeRecord>('records').clear();
    await Hive.box<HiveTimeRecord>('records').close();
  });

  group('RecordsBloc', () {
    blocTest<RecordsBloc, RecordsState>(
      'emits RecordsLoaded with empty list on RecordsLoaded',
      build: () => RecordsBloc(repo),
      act: (bloc) => bloc.add(LoadRecords()),
      expect: () => [const RecordsLoading(), const RecordsLoaded([])],
    );

    blocTest<RecordsBloc, RecordsState>(
      'emits RecordsLoaded with 1 record on RecordAdded without a loading flash',
      // main.dart always kicks off with LoadRecords; mutations then refresh
      // silently and the repository-driven reload dedupes to a single state.
      build: () => RecordsBloc(repo)..add(LoadRecords()),
      wait: const Duration(milliseconds: 100),
      act: (bloc) {
        bloc.add(
          RecordAdded(
            TimeRecord(
              id: '',
              categoryId: 'work',
              startTime: DateTime(2026, 7, 9, 8, 0),
              endTime: DateTime(2026, 7, 9, 9, 0),
            ),
          ),
        );
      },
      expect: () => [
        const RecordsLoading(),
        const RecordsLoaded([]),
        isA<RecordsLoaded>(),
      ],
      verify: (bloc) {
        final state = bloc.state as RecordsLoaded;
        expect(state.records.length, 1);
        expect(state.records.first.categoryId, 'work');
      },
    );
    blocTest<RecordsBloc, RecordsState>(
      'reloads when the repository changes outside the bloc',
      build: () => RecordsBloc(repo)..add(LoadRecords()),
      act: (bloc) async {
        // Let the initial LoadRecords settle before writing outside the bloc.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await repo.add(
          TimeRecord(
            id: 'external',
            categoryId: 'work',
            startTime: DateTime(2026, 7, 9, 8, 0),
            endTime: DateTime(2026, 7, 9, 9, 0),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      },
      expect: () => [
        const RecordsLoading(),
        const RecordsLoaded([]),
        isA<RecordsLoaded>(),
      ],
      verify: (bloc) {
        final state = bloc.state as RecordsLoaded;
        expect(state.records.length, 1);
        expect(state.records.first.id, 'external');
      },
    );
  });
}
