// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_time_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveTimeRecordAdapter extends TypeAdapter<HiveTimeRecord> {
  @override
  final typeId = 0;

  @override
  HiveTimeRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveTimeRecord(
      id: fields[0] as String,
      categoryId: fields[1] as String?,
      startTime: fields[2] as DateTime,
      endTime: fields[3] as DateTime,
      note: fields[4] as String?,
      createdAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveTimeRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.categoryId)
      ..writeByte(2)
      ..write(obj.startTime)
      ..writeByte(3)
      ..write(obj.endTime)
      ..writeByte(4)
      ..write(obj.note)
      ..writeByte(5)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveTimeRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
