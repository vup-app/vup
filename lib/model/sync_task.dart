import 'package:hive/hive.dart';

part 'sync_task.g.dart';

@HiveType(typeId: 10)
class SyncTask extends HiveObject{
  @HiveField(1)
  final String remotePath;
  @HiveField(2)
  String? localPath;
  @HiveField(3)
  SyncMode mode;
  @HiveField(4)
  bool watch = false;
  @HiveField(5)
  int interval; // In seconds

  SyncTask({
    required this.remotePath,
    this.localPath,
    this.mode = SyncMode.sendAndReceive,
    this.watch = false,
    this.interval = 0,
  });
}

@HiveType(typeId: 11)
enum SyncMode {
  @HiveField(0)
  sendAndReceive,
  @HiveField(1)
  sendOnly,
  @HiveField(2)
  receiveOnly,
}
