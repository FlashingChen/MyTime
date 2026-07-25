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

  test('background policy keeps the remote entity for a same-ID conflict', () {
    final local = _snapshot(record: _record('a', '后台旧版本'));
    final remote = _snapshot(record: _record('a', '前台新版本'));

    final merged = service.merge(
      local: local,
      remote: remote,
      conflictPolicy: SyncConflictPolicy.preferRemote,
    );

    expect(merged.records.single.note, '前台新版本');
  });

  test('background policy keeps a valid remote tombstone over an entity', () {
    final local = _snapshot(record: _record('a', '后台旧版本'));
    final remote = _snapshot(
      metadata: SyncMetadata(
        records: {
          'a': SyncEntityMetadata(
            kind: SyncEntityKind.record,
            id: 'a',
            deletedAt: DateTime.utc(2026, 7, 21),
          ),
        },
      ),
    );

    final merged = service.merge(
      local: local,
      remote: remote,
      conflictPolicy: SyncConflictPolicy.preferRemote,
    );

    expect(merged.records, isEmpty);
    expect(merged.metadata.records['a']!.deletedAt, DateTime.utc(2026, 7, 21));
  });

  test(
    'background policy keeps a newer local tombstone over an old remote entity',
    () {
      final local = _snapshot(
        metadata: SyncMetadata(
          records: {
            'a': SyncEntityMetadata(
              kind: SyncEntityKind.record,
              id: 'a',
              deletedAt: DateTime.utc(2026, 7, 21),
            ),
          },
        ),
      );
      final remote = _snapshot(
        record: _record('a', '后台旧版本'),
        metadata: _recordMetadata('a', updatedAt: DateTime.utc(2026, 7, 20)),
      );

      final merged = service.merge(
        local: local,
        remote: remote,
        conflictPolicy: SyncConflictPolicy.preferRemote,
      );

      expect(merged.records, isEmpty);
      expect(
        merged.metadata.records['a']!.deletedAt,
        DateTime.utc(2026, 7, 21),
      );
    },
  );

  test(
    'background policy uploads an entity absent from the remote document',
    () {
      final local = _snapshot(record: _record('a', '后台创建'));
      final remote = _snapshot();

      final merged = service.merge(
        local: local,
        remote: remote,
        conflictPolicy: SyncConflictPolicy.preferRemote,
      );

      expect(merged.records.single.note, '后台创建');
    },
  );

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

  test('keeps a newer record update over an older tombstone', () {
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

    expect(merged.records.single.note, '重新创建');
    expect(merged.metadata.records['a']!.updatedAt, DateTime.utc(2026, 7, 21));
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

  test('keeps a newer record tombstone over an older remote update', () {
    final local = _snapshot(
      metadata: SyncMetadata(
        records: {
          'a': SyncEntityMetadata(
            kind: SyncEntityKind.record,
            id: 'a',
            deletedAt: DateTime.utc(2026, 7, 21),
          ),
        },
      ),
    );
    final remote = _snapshot(
      record: _record('a', '远端更新'),
      metadata: SyncMetadata(
        records: {
          'a': SyncEntityMetadata(
            kind: SyncEntityKind.record,
            id: 'a',
            updatedAt: DateTime.utc(2026, 7, 20),
          ),
        },
      ),
    );

    final merged = service.merge(local: local, remote: remote);

    expect(merged.records, isEmpty);
    expect(merged.metadata.records['a']!.deletedAt, DateTime.utc(2026, 7, 21));
  });

  test(
    'foreground policy keeps its tombstone when record versions are equal',
    () {
      final local = _snapshot(
        metadata: _recordMetadata('a', deletedAt: DateTime.utc(2026, 7, 21)),
      );
      final remote = _snapshot(
        record: _record('a', '远端同版本'),
        metadata: _recordMetadata('a', updatedAt: DateTime.utc(2026, 7, 21)),
      );

      final merged = service.merge(local: local, remote: remote);

      expect(merged.records, isEmpty);
      expect(
        merged.metadata.records['a']!.deletedAt,
        DateTime.utc(2026, 7, 21),
      );
    },
  );

  test(
    'background policy keeps its tombstone when record versions are equal',
    () {
      final local = _snapshot(
        record: _record('a', '后台同版本'),
        metadata: _recordMetadata('a', updatedAt: DateTime.utc(2026, 7, 21)),
      );
      final remote = _snapshot(
        metadata: _recordMetadata('a', deletedAt: DateTime.utc(2026, 7, 21)),
      );

      final merged = service.merge(
        local: local,
        remote: remote,
        conflictPolicy: SyncConflictPolicy.preferRemote,
      );

      expect(merged.records, isEmpty);
      expect(
        merged.metadata.records['a']!.deletedAt,
        DateTime.utc(2026, 7, 21),
      );
    },
  );

  test('foreground policy keeps its entity when record versions are equal', () {
    final local = _snapshot(
      record: _record('a', '本地同版本'),
      metadata: _recordMetadata('a', updatedAt: DateTime.utc(2026, 7, 21)),
    );
    final remote = _snapshot(
      metadata: _recordMetadata('a', deletedAt: DateTime.utc(2026, 7, 21)),
    );

    final merged = service.merge(local: local, remote: remote);

    expect(merged.records.single.note, '本地同版本');
    expect(merged.metadata.records['a']!.updatedAt, DateTime.utc(2026, 7, 21));
  });

  test('keeps a newer category update over an older tombstone', () {
    final local = _snapshot(
      categories: const [Category(id: 'life', name: '本地', color: '#123456')],
      metadata: _categoryMetadata('work', deletedAt: DateTime.utc(2026, 7, 20)),
    );
    final remote = _snapshot(
      categories: const [Category(id: 'work', name: '远端新版本', color: '#654321')],
      metadata: _categoryMetadata('work', updatedAt: DateTime.utc(2026, 7, 21)),
    );

    final merged = service.merge(local: local, remote: remote);

    expect(merged.categories.map((item) => item.id), contains('work'));
    expect(
      merged.metadata.categories['work']!.updatedAt,
      DateTime.utc(2026, 7, 21),
    );
  });

  test('keeps a newer category tombstone over an older remote update', () {
    final local = _snapshot(
      categories: const [Category(id: 'life', name: '本地', color: '#123456')],
      metadata: _categoryMetadata('work', deletedAt: DateTime.utc(2026, 7, 21)),
    );
    final remote = _snapshot(
      categories: const [Category(id: 'work', name: '远端旧版本', color: '#654321')],
      metadata: _categoryMetadata('work', updatedAt: DateTime.utc(2026, 7, 20)),
    );

    final merged = service.merge(
      local: local,
      remote: remote,
      conflictPolicy: SyncConflictPolicy.preferRemote,
    );

    expect(merged.categories.map((item) => item.id), isNot(contains('work')));
    expect(
      merged.metadata.categories['work']!.deletedAt,
      DateTime.utc(2026, 7, 21),
    );
  });
}

SyncMetadata _recordMetadata(
  String id, {
  DateTime? updatedAt,
  DateTime? deletedAt,
}) => SyncMetadata(
  records: {
    id: SyncEntityMetadata(
      kind: SyncEntityKind.record,
      id: id,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    ),
  },
);

SyncMetadata _categoryMetadata(
  String id, {
  DateTime? updatedAt,
  DateTime? deletedAt,
}) => SyncMetadata(
  categories: {
    id: SyncEntityMetadata(
      kind: SyncEntityKind.category,
      id: id,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    ),
  },
);

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
