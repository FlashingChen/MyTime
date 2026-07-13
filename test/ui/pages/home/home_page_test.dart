import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/blocs/records/records_bloc.dart';
import 'package:mytime/blocs/records/records_state.dart';
import 'package:mytime/blocs/timer/timer_bloc.dart';
import 'package:mytime/blocs/timer/timer_event.dart';
import 'package:mytime/blocs/timer/timer_state.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/repositories/active_timer_repository.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/ui/pages/home/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late _MemoryRecordsRepository repo;

  setUp(() {
    repo = _MemoryRecordsRepository();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows 00:00 and start button in idle state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => TimerBloc(ActiveTimerRepository())),
            BlocProvider(create: (_) => RecordsBloc(repo)),
          ],
          child: const HomePage(),
        ),
      ),
    );
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('点击开始按钮开始计时'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'requires an explicit choice before dismissing a completed timer',
    (tester) async {
      final timerBloc = TimerBloc(ActiveTimerRepository());
      final recordsBloc = RecordsBloc(repo);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: timerBloc),
              BlocProvider.value(value: recordsBloc),
            ],
            child: const HomePage(),
          ),
        ),
      );

      timerBloc.add(TimerStarted());
      await tester.pump();
      timerBloc.add(TimerStopped());
      await tester.pumpAndSettle();

      expect(find.text('记录详情'), findsOneWidget);
      final barrier = find.byWidgetPredicate(
        (widget) => widget is ModalBarrier,
      );
      final barriers = tester.widgetList<ModalBarrier>(barrier);
      expect(barriers, isNotEmpty);
      expect(
        barriers.every((modalBarrier) => !modalBarrier.dismissible),
        isTrue,
      );
      expect(
        tester.widget<BottomSheet>(find.byType(BottomSheet)).enableDrag,
        isFalse,
      );

      await tester.tap(find.text('放弃记录'));
      await tester.pumpAndSettle();

      expect(find.text('记录详情'), findsNothing);
      expect(timerBloc.state, isA<TimerInitial>());

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'saving a completed timer closes the sheet and resets the timer',
    (tester) async {
      final timerBloc = TimerBloc(ActiveTimerRepository());
      final recordsBloc = RecordsBloc(repo);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: timerBloc),
              BlocProvider.value(value: recordsBloc),
            ],
            child: const HomePage(),
          ),
        ),
      );

      timerBloc.add(TimerStarted());
      await tester.pump();
      timerBloc.add(TimerStopped());
      await tester.pumpAndSettle();

      final confirmButton = find.text('确认保存');
      await tester.ensureVisible(confirmButton);
      await tester.tap(confirmButton);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      expect(recordsBloc.state, isA<RecordsLoaded>());
      expect(find.text('记录详情'), findsNothing);
      expect(timerBloc.state, isA<TimerInitial>());
      expect(repo.getAll(), hasLength(1));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

class _MemoryRecordsRepository implements RecordsRepository {
  final Map<String, TimeRecord> _records = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<TimeRecord> add(TimeRecord record) async {
    final saved = record.id.isEmpty
        ? record.copyWith(id: 'record-${_records.length + 1}')
        : record;
    _records[saved.id] = saved;
    _changes.add(null);
    return saved;
  }

  @override
  Future<void> clearCategory(String categoryId) async {
    for (final record in _records.values.toList()) {
      if (record.categoryId == categoryId) {
        _records[record.id] = record.copyWith(categoryId: null);
      }
    }
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    _records.remove(id);
    _changes.add(null);
  }

  @override
  List<TimeRecord> getAll() => _records.values.toList();

  @override
  List<TimeRecord> getByDate(DateTime date) => getAll();

  @override
  List<TimeRecord> getByRange(DateTime start, DateTime end) => getAll();

  @override
  Future<void> reassignCategory(
    String fromCategoryId,
    String toCategoryId,
  ) async {
    for (final record in _records.values.toList()) {
      if (record.categoryId == fromCategoryId) {
        _records[record.id] = record.copyWith(categoryId: toCategoryId);
      }
    }
    _changes.add(null);
  }

  @override
  Future<void> update(TimeRecord record) async {
    _records[record.id] = record;
    _changes.add(null);
  }
}
