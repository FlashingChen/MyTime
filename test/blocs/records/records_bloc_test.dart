import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mytime/blocs/records/records_bloc.dart';
import 'package:mytime/blocs/records/records_event.dart';
import 'package:mytime/blocs/records/records_state.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/repositories/record_repository.dart';

void main() {
  late RecordRepository repo;

  setUpAll(() async {
    Hive.init('test_hive_records_bloc');
    Hive.registerAdapter(TimeRecordAdapter());
  });

  setUp(() async {
    final box = await Hive.openBox<TimeRecord>('records');
    repo = RecordRepository(box);
  });

  tearDown(() async {
    await Hive.box<TimeRecord>('records').clear();
    await Hive.box<TimeRecord>('records').close();
  });

  group('RecordsBloc', () {
    blocTest<RecordsBloc, RecordsState>(
      'emits RecordsLoadSuccess with empty list on RecordsLoaded',
      build: () => RecordsBloc(repo),
      act: (bloc) => bloc.add(RecordsLoaded()),
      expect: () => [
        const RecordsLoading(),
        const RecordsLoadSuccess([]),
      ],
    );

    blocTest<RecordsBloc, RecordsState>(
      'emits RecordsLoadSuccess with 1 record on RecordAdded',
      build: () => RecordsBloc(repo),
      wait: const Duration(milliseconds: 100),
      act: (bloc) {
        bloc.add(RecordAdded(TimeRecord(
          id: '',
          categoryId: 'work',
          startTime: DateTime(2026, 7, 9, 8, 0),
          endTime: DateTime(2026, 7, 9, 9, 0),
        )));
      },
      expect: () => [
        isA<RecordsLoadSuccess>(),
      ],
      verify: (bloc) {
        final state = bloc.state as RecordsLoadSuccess;
        expect(state.records.length, 1);
        expect(state.records.first.categoryId, 'work');
      },
    );
  });
}