import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/hive_impl.dart' show HiveImpl;
import 'package:mytime/data/dtos/hive_category.dart';
import 'package:mytime/data/dtos/hive_time_record.dart';

void main() {
  test(
    'opens legacy Hive records and categories with the DTO adapters',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'mytime_hive_v1_',
      );
      addTearDown(() => directory.delete(recursive: true));

      await _writeLegacyBoxes(directory.path);

      Hive.init(directory.path);
      Hive.registerAdapter(HiveTimeRecordAdapter());
      Hive.registerAdapter(HiveCategoryAdapter());
      addTearDown(Hive.close);

      final records = await Hive.openBox<HiveTimeRecord>('records');
      final categories = await Hive.openBox<HiveCategory>('categories');

      final record = records.get('legacy-record')!.toDomain();
      expect(record.id, 'legacy-record');
      expect(record.categoryId, 'legacy-category');
      expect(record.startTime, DateTime(2026, 7, 10, 9));
      expect(record.endTime, DateTime(2026, 7, 10, 10));
      expect(record.note, 'legacy note');
      expect(record.createdAt, isA<DateTime>());
      expect(categories.get('legacy-category')!.toDomain().name, '旧分类');
    },
  );
}

Future<void> _writeLegacyBoxes(String path) async {
  final legacyHive = HiveImpl();
  legacyHive.init(path);
  legacyHive.registerAdapter(_LegacyTimeRecordAdapter());
  legacyHive.registerAdapter(_LegacyCategoryAdapter());
  final records = await legacyHive.openBox<_LegacyTimeRecord>('records');
  final categories = await legacyHive.openBox<_LegacyCategory>('categories');
  await categories.put(
    'legacy-category',
    const _LegacyCategory('legacy-category', '旧分类', '#123456'),
  );
  await records.put(
    'legacy-record',
    _LegacyTimeRecord(
      id: 'legacy-record',
      categoryId: 'legacy-category',
      startTime: DateTime(2026, 7, 10, 9),
      endTime: DateTime(2026, 7, 10, 10),
      note: 'legacy note',
    ),
  );
  await legacyHive.close();
}

class _LegacyTimeRecord {
  const _LegacyTimeRecord({
    required this.id,
    required this.categoryId,
    required this.startTime,
    required this.endTime,
    required this.note,
  });

  final String id;
  final String? categoryId;
  final DateTime startTime;
  final DateTime endTime;
  final String? note;
}

class _LegacyTimeRecordAdapter extends TypeAdapter<_LegacyTimeRecord> {
  @override
  final int typeId = 0;

  @override
  _LegacyTimeRecord read(BinaryReader reader) =>
      throw UnsupportedError('Legacy fixture only writes data');

  @override
  void write(BinaryWriter writer, _LegacyTimeRecord value) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(value.id)
      ..writeByte(1)
      ..write(value.categoryId)
      ..writeByte(2)
      ..write(value.startTime)
      ..writeByte(3)
      ..write(value.endTime)
      ..writeByte(4)
      ..write(value.note);
  }
}

class _LegacyCategory {
  const _LegacyCategory(this.id, this.name, this.color);

  final String id;
  final String name;
  final String color;
}

class _LegacyCategoryAdapter extends TypeAdapter<_LegacyCategory> {
  @override
  final int typeId = 1;

  @override
  _LegacyCategory read(BinaryReader reader) =>
      throw UnsupportedError('Legacy fixture only writes data');

  @override
  void write(BinaryWriter writer, _LegacyCategory value) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(value.id)
      ..writeByte(1)
      ..write(value.name)
      ..writeByte(2)
      ..write(value.color);
  }
}
