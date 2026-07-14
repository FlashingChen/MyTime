import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/blocs/records/records.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/ui/pages/settings/record_management/record_management_page.dart';

void main() {
  testWidgets('puts add in the header and has no floating overlay', (
    tester,
  ) async {
    await _pumpPage(tester);

    expect(find.byKey(const Key('record-management-add')), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('keeps the last record actions visible and tappable', (
    tester,
  ) async {
    await _pumpPage(tester, recordCount: 12);
    final delete = find.byKey(const ValueKey<String>('record-delete-record-0'));

    await tester.scrollUntilVisible(
      delete,
      220,
      scrollable: find.byType(Scrollable),
    );
    expect(tester.getRect(delete).bottom, lessThanOrEqualTo(640));
    await tester.tap(delete);
    await tester.pumpAndSettle();

    expect(find.text('删除记录'), findsOneWidget);
    expect(find.text('删除后无法恢复。'), findsOneWidget);
  });

  testWidgets('opens the shared editor from an edit action', (tester) async {
    await _pumpPage(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('record-edit-record-0')),
    );
    await tester.pumpAndSettle();

    expect(find.text('编辑记录'), findsOneWidget);
    expect(find.byKey(const Key('record-editor-start-date')), findsOneWidget);
    expect(find.byKey(const Key('record-editor-end-time')), findsOneWidget);
  });

  testWidgets('dispatches an edited record without changing its identity', (
    tester,
  ) async {
    final repository = _MemoryRecordsRepository(_seedRecords(1));
    await _pumpPage(tester, repository: repository);

    await tester.tap(
      find.byKey(const ValueKey<String>('record-edit-record-0')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('record-editor-note')),
      '更新后的备注',
    );
    final save = find.byKey(const Key('record-editor-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.getAll().single.id, 'record-0');
    expect(repository.getAll().single.note, '更新后的备注');
  });

  testWidgets('deletes only after confirmation', (tester) async {
    final repository = _MemoryRecordsRepository(_seedRecords(1));
    await _pumpPage(tester, repository: repository);

    await tester.tap(
      find.byKey(const ValueKey<String>('record-delete-record-0')),
    );
    await tester.pumpAndSettle();
    expect(repository.getAll(), hasLength(1));

    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();
    expect(repository.getAll(), isEmpty);
  });

  testWidgets('shows both dates for a cross-day record', (tester) async {
    final repository = _MemoryRecordsRepository([
      TimeRecord(
        id: 'overnight',
        categoryId: 'work',
        startTime: DateTime(2026, 7, 14, 23, 30),
        endTime: DateTime(2026, 7, 15, 1),
      ),
    ]);
    await _pumpPage(tester, repository: repository);

    expect(find.text('2026-07-14 23:30 – 2026-07-15 01:00'), findsOneWidget);
  });
}

Future<_MemoryRecordsRepository> _pumpPage(
  WidgetTester tester, {
  int recordCount = 1,
  _MemoryRecordsRepository? repository,
}) async {
  tester.view.physicalSize = const Size(390, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final result =
      repository ?? _MemoryRecordsRepository(_seedRecords(recordCount));
  addTearDown(result.close);
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider(
        create: (_) => RecordsBloc(result)..add(LoadRecords()),
        child: const RecordManagementPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return result;
}

List<TimeRecord> _seedRecords(int count) => List.generate(
  count,
  (index) => TimeRecord(
    id: 'record-$index',
    categoryId: 'work',
    startTime: DateTime(2026, 7, 14, 8).add(Duration(hours: index)),
    endTime: DateTime(2026, 7, 14, 9).add(Duration(hours: index)),
    note: '记录 $index',
  ),
);

class _MemoryRecordsRepository implements RecordsRepository {
  _MemoryRecordsRepository(Iterable<TimeRecord> records)
    : _records = records.toList();

  final StreamController<void> _changes = StreamController<void>.broadcast();
  final List<TimeRecord> _records;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  List<TimeRecord> getAll() {
    final result = List<TimeRecord>.of(_records);
    result.sort((a, b) => b.startTime.compareTo(a.startTime));
    return result;
  }

  @override
  List<TimeRecord> getByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    return getByRange(start, start.add(const Duration(days: 1)));
  }

  @override
  List<TimeRecord> getByRange(DateTime start, DateTime end) => getAll()
      .where(
        (record) =>
            record.startTime.isBefore(end) && record.endTime.isAfter(start),
      )
      .toList();

  @override
  Future<TimeRecord> add(TimeRecord record) async {
    final saved = record.id.isEmpty
        ? record.copyWith(id: 'record-${_records.length}')
        : record;
    _records.add(saved);
    _changes.add(null);
    return saved;
  }

  @override
  Future<void> update(TimeRecord record) async {
    final index = _records.indexWhere((item) => item.id == record.id);
    _records[index] = record;
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    _records.removeWhere((record) => record.id == id);
    _changes.add(null);
  }

  @override
  Future<void> reassignCategory(
    String fromCategoryId,
    String toCategoryId,
  ) async {
    for (var index = 0; index < _records.length; index++) {
      if (_records[index].categoryId == fromCategoryId) {
        _records[index] = _records[index].copyWith(categoryId: toCategoryId);
      }
    }
    _changes.add(null);
  }

  @override
  Future<void> clearCategory(String categoryId) async {
    for (var index = 0; index < _records.length; index++) {
      if (_records[index].categoryId == categoryId) {
        _records[index] = _records[index].copyWith(categoryId: null);
      }
    }
    _changes.add(null);
  }

  Future<void> close() => _changes.close();
}
