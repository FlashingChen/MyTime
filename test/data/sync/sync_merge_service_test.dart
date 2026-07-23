import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/sync/sync_merge_service.dart';
import 'package:mytime/data/sync/sync_metadata.dart';
import 'package:mytime/data/sync/sync_port.dart';

void main() {
  final service = SyncMergeService(clock: () => DateTime.utc(2026, 7, 22));

  test('keeps unrelated entities and resolves conflicting records locally', () {
    final local = _snapshot(record: _record('a', '本机'));
    final remote = _snapshot(
      record: _record('a', '远端'),
      extraRecord: _record('b', '远端新增'),
    );

    final merged = service.merge(local: local, remote: remote);

    expect(merged.records.map((item) => item.id), containsAll(['a', 'b']));
    expect(merged.records.singleWhere((item) => item.id == 'a').note, '本机');
  });

  test(
    'tombstone prevents an old remote record from returning for 90 days',
    () {
      final local = _snapshot(
        metadata: SyncMetadata(
          records: {
            'a': SyncEntityMetadata(
              kind: SyncEntityKind.record,
              id: 'a',
              deletedAt: DateTime.utc(2026, 7, 1),
            ),
          },
        ),
      );
      final remote = _snapshot(record: _record('a', '旧副本'));

      final merged = service.merge(local: local, remote: remote);

      expect(merged.records, isEmpty);
      expect(merged.metadata.records['a']!.deletedAt, DateTime.utc(2026, 7, 1));
    },
  );

  test('clears category reference when the category is tombstoned', () {
    final local = _snapshot(
      categories: const [
        Category(id: 'work', name: '工作', color: '#123456'),
        Category(id: 'life', name: '生活', color: '#654321'),
      ],
      metadata: SyncMetadata(
        categories: {
          'work': SyncEntityMetadata(
            kind: SyncEntityKind.category,
            id: 'work',
            deletedAt: DateTime.utc(2026, 7, 1),
          ),
        },
      ),
    );
    final remote = _snapshot(record: _record('a', '远端', categoryId: 'work'));

    final merged = service.merge(local: local, remote: remote);

    expect(merged.records.single.categoryId, isNull);
  });

  test('keeps an entity updated after an older remote tombstone', () {
    final local = _snapshot(
      record: _record('a', '重新创建'),
      metadata: SyncMetadata(
        records: {
          'a': SyncEntityMetadata(
            kind: SyncEntityKind.record,
            id: 'a',
            updatedAt: DateTime.utc(2026, 7, 21),
          ),
        },
      ),
    );
    final remote = _snapshot(
      metadata: SyncMetadata(
        records: {
          'a': SyncEntityMetadata(
            kind: SyncEntityKind.record,
            id: 'a',
            deletedAt: DateTime.utc(2026, 7, 20),
          ),
        },
      ),
    );

    final merged = service.merge(local: local, remote: remote);

    expect(merged.records.single.id, 'a');
    expect(merged.metadata.records['a']!.deletedAt, isNull);
  });

  test('allows an entity when its tombstone expired more than 90 days ago', () {
    final local = _snapshot();
    final remote = _snapshot(
      record: _record('a', '旧副本'),
      metadata: SyncMetadata(
        records: {
          'a': SyncEntityMetadata(
            kind: SyncEntityKind.record,
            id: 'a',
            deletedAt: DateTime.utc(2026, 4, 22),
          ),
        },
      ),
    );

    final merged = service.merge(local: local, remote: remote);

    expect(merged.records.single.id, 'a');
    expect(merged.metadata.records['a'], isNull);
  });
}

SyncSnapshot _snapshot({
  TimeRecord? record,
  TimeRecord? extraRecord,
  SyncMetadata? metadata,
  List<Category>? categories,
}) => SyncSnapshot(
  updatedAt: DateTime.utc(2026, 7, 1),
  categories:
      categories ?? const [Category(id: 'work', name: '工作', color: '#123456')],
  records: [if (record != null) record, if (extraRecord != null) extraRecord],
  metadata: metadata ?? const SyncMetadata(),
);

TimeRecord _record(String id, String note, {String? categoryId}) => TimeRecord(
  id: id,
  categoryId: categoryId,
  note: note,
  startTime: DateTime.utc(2026, 7, 1, 9),
  endTime: DateTime.utc(2026, 7, 1, 10),
);
