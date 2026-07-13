import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/records/records_state.dart';
import 'package:mytime/blocs/stats/stats_event.dart';
import 'package:mytime/blocs/stats/stats_state.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/stats/stats_metrics.dart';

/// Transforms the shared saved-record state into metrics outside widget builds.
class StatsBloc extends Bloc<StatsEvent, StatsState> {
  StatsBloc(
    StateStreamable<RecordsState> recordsSource, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const StatsInitial()) {
    on<StatsRangeChanged>(_onRangeChanged);
    on<StatsRecordsChanged>(_onRecordsChanged);
    _recordsSubscription = recordsSource.stream.listen((state) {
      if (state case RecordsLoaded(:final records)) {
        add(StatsRecordsChanged(List<TimeRecord>.unmodifiable(records)));
      }
    });

    final initialState = recordsSource.state;
    if (initialState case RecordsLoaded(:final records)) {
      add(StatsRecordsChanged(List<TimeRecord>.unmodifiable(records)));
    }
  }

  final DateTime Function() _clock;
  late final StreamSubscription<RecordsState> _recordsSubscription;
  List<TimeRecord> _records = const [];
  StatsRange _range = StatsRange.week;

  void _onRangeChanged(StatsRangeChanged event, Emitter<StatsState> emit) {
    _range = event.range;
    _emitMetrics(emit);
  }

  void _onRecordsChanged(StatsRecordsChanged event, Emitter<StatsState> emit) {
    _records = event.records;
    _emitMetrics(emit);
  }

  void _emitMetrics(Emitter<StatsState> emit) {
    emit(StatsLoaded(StatsMetrics.forRange(_records, _range, _clock())));
  }

  @override
  Future<void> close() async {
    await _recordsSubscription.cancel();
    return super.close();
  }
}
