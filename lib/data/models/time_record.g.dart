// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'time_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TimeRecordAdapter extends TypeAdapter<TimeRecord> {
  @override
  final typeId = 0;

  @override
  TimeRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimeRecord(
      id: fields[0] as String,
      categoryId: fields[1] as String?,
      startTime: fields[2] as DateTime,
      endTime: fields[3] as DateTime,
      note: fields[4] as String?,
      createdAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TimeRecord obj) {
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
      other is TimeRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
