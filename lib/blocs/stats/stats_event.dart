import 'package:equatable/equatable.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/stats/stats_metrics.dart';

/// Base event for the statistics presentation BLoC.
sealed class StatsEvent extends Equatable {
  const StatsEvent();

  @override
  List<Object?> get props => const [];
}

/// Requests metrics for a different calendar range.
class StatsRangeChanged extends StatsEvent {
  const StatsRangeChanged(this.range);

  final StatsRange range;

  @override
  List<Object?> get props => [range];
}

/// Supplies a fresh immutable snapshot from the saved-record state source.
class StatsRecordsChanged extends StatsEvent {
  const StatsRecordsChanged(this.records);

  final List<TimeRecord> records;

  @override
  List<Object?> get props => [records];
}
