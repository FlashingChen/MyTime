import 'package:equatable/equatable.dart';
import 'package:mytime/ui/pages/stats/stats_metrics.dart';

/// Base state for statistics presentation.
sealed class StatsState extends Equatable {
  const StatsState();

  @override
  List<Object?> get props => const [];
}

/// State before the records source has produced a saved-record list.
class StatsInitial extends StatsState {
  const StatsInitial();
}

/// A fully calculated, immutable statistics view model.
class StatsLoaded extends StatsState {
  const StatsLoaded(this.metrics);

  final StatsMetrics metrics;

  @override
  List<Object?> get props => [metrics];
}
