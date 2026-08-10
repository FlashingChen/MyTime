import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/blocs/records/records_state.dart';
import 'package:mytime/blocs/stats/stats_bloc.dart';
import 'package:mytime/blocs/stats/stats_event.dart';
import 'package:mytime/blocs/stats/stats_state.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/stats/stats_metrics.dart';

void main() {
  final now = DateTime(2026, 7, 12, 12);

  group('StatsBloc', () {
    late _RecordsStateCubit source;

    blocTest<StatsBloc, StatsState>(
      'derives metrics for the current range from the initial records state',
      build: () => StatsBloc(
        _RecordsStateCubit(
          RecordsLoaded([
            TimeRecord(
              id: 'work',
              categoryId: 'work',
              startTime: DateTime(2026, 7, 12, 9),
              endTime: DateTime(2026, 7, 12, 10, 30),
            ),
          ]),
        ),
        clock: () => now,
      ),
      expect: () => [
        isA<StatsLoaded>()
            .having((state) => state.metrics.range, 'range', StatsRange.week)
            .having(
              (state) => state.metrics.total,
              'total',
              const Duration(minutes: 90),
            ),
      ],
    );

    blocTest<StatsBloc, StatsState>(
      'recomputes metrics when the user selects another range',
      build: () => StatsBloc(
        _RecordsStateCubit(
          RecordsLoaded([
            TimeRecord(
              id: 'previous-month',
              startTime: DateTime(2026, 6, 30, 23),
              endTime: DateTime(2026, 7, 1, 1),
            ),
          ]),
        ),
        clock: () => now,
      ),
      act: (bloc) => bloc.add(const StatsRangeChanged(StatsRange.month)),
      expect: () => [
        isA<StatsLoaded>(),
        isA<StatsLoaded>()
            .having((state) => state.metrics.range, 'range', StatsRange.month)
            .having(
              (state) => state.metrics.total,
              'total',
              const Duration(hours: 1),
            ),
      ],
    );

    blocTest<StatsBloc, StatsState>(
      'recomputes day metrics when the day anchor changes',
      build: () => StatsBloc(
        _RecordsStateCubit(
          RecordsLoaded([
            TimeRecord(
              id: 'today',
              startTime: DateTime(2026, 7, 12, 9),
              endTime: DateTime(2026, 7, 12, 10, 30),
            ),
            TimeRecord(
              id: 'yesterday',
              startTime: DateTime(2026, 7, 11, 20),
              endTime: DateTime(2026, 7, 11, 21),
            ),
          ]),
        ),
        clock: () => now,
      ),
      act: (bloc) {
        bloc.add(const StatsRangeChanged(StatsRange.day));
        bloc.add(StatsDayChanged(DateTime(2026, 7, 11)));
      },
      expect: () => [
        isA<StatsLoaded>(),
        isA<StatsLoaded>()
            .having((state) => state.metrics.range, 'range', StatsRange.day)
            .having(
              (state) => state.metrics.total,
              'total',
              const Duration(minutes: 90),
            ),
        isA<StatsLoaded>()
            .having(
              (state) => state.metrics.total,
              'total',
              const Duration(minutes: 60),
            )
            .having(
              (state) => state.metrics.anchorDate,
              'anchorDate',
              DateTime(2026, 7, 11),
            )
            .having((state) => state.metrics.isToday, 'isToday', isFalse),
      ],
    );

    blocTest<StatsBloc, StatsState>(
      'recomputes when RecordsBloc publishes an updated record list',
      build: () {
        source = _RecordsStateCubit(const RecordsLoaded([]));
        return StatsBloc(source, clock: () => now);
      },
      act: (bloc) {
        source.publish(
          RecordsLoaded([
            TimeRecord(
              id: 'later',
              startTime: DateTime(2026, 7, 12, 10),
              endTime: DateTime(2026, 7, 12, 11),
            ),
          ]),
        );
      },
      expect: () => [
        isA<StatsLoaded>(),
        isA<StatsLoaded>().having(
          (state) => state.metrics.total,
          'total',
          const Duration(hours: 1),
        ),
      ],
    );
  });
}

class _RecordsStateCubit extends Cubit<RecordsState> {
  _RecordsStateCubit(super.initialState);

  void publish(RecordsState state) => emit(state);
}
