// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncModeAdapter extends TypeAdapter<SyncMode> {
  @override
  final int typeId = 11;

  @override
  SyncMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SyncMode.sendAndReceive;
      case 1:
        return SyncMode.sendOnly;
      case 2:
        return SyncMode.receiveOnly;
      default:
        return SyncMode.sendAndReceive;
    }
  }

  @override
  void write(BinaryWriter writer, SyncMode obj) {
    switch (obj) {
      case SyncMode.sendAndReceive:
        writer.writeByte(0);
        break;
      case SyncMode.sendOnly:
        writer.writeByte(1);
        break;
      case SyncMode.receiveOnly:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SyncTaskAdapter extends TypeAdapter<SyncTask> {
  @override
  final int typeId = 10;

  @override
  SyncTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncTask(
      remotePath: fields[1] as String,
      localPath: fields[2] as String?,
      mode: fields[3] as SyncMode,
      watch: fields[4] as bool,
      interval: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SyncTask obj) {
    writer
      ..writeByte(5)
      ..writeByte(1)
      ..write(obj.remotePath)
      ..writeByte(2)
      ..write(obj.localPath)
      ..writeByte(3)
      ..write(obj.mode)
      ..writeByte(4)
      ..write(obj.watch)
      ..writeByte(5)
      ..write(obj.interval);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
