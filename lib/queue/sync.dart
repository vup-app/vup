import 'dart:io';

import 'package:vup/generic/state.dart';
import 'package:vup/model/sync_task.dart';

import 'task.dart';

class SyncQueueTask extends QueueTask {
  final String id;

  final List<String> dependencies;

  @override
  final threadPool = 'sync';

  @override
  double progress = 0;

  final Directory dir;
  final String remotePath;
  final SyncMode mode;

  SyncQueueTask({
    required this.id,
    required this.dir,
    required this.remotePath,
    required this.mode,
    required this.dependencies,
  });

  @override
  Future<void> execute() {
    logger.verbose('sync "$remotePath" "${dir.path}" $mode');
    return storageService.syncSingleDirectory(this);
  }
}
