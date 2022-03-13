import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path/path.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/model/sync_task.dart';
import 'package:vup/service/storage.dart';
import 'package:xdg_directories/xdg_directories.dart';

Future<void> initAppGeneric({required bool isRunningInFlutterMode}) async {
  // TODO Store Hive thumbnail and directory cache in data directory

  final tempDir = Directory('/tmp');
  Directory? configDir = Platform.isLinux ? configHome : null;

  final vupConfigDir = join(configDir!.path, 'vup');
  final vupTempDir = join(tempDir.path, 'vup');

  await logger.init(vupTempDir);

  String? vupDataDir;

  vupDataDir = join(dataHome.path, 'vup');

  // TODO Use custom directories for Docker

  logger.info('vupConfigDir $vupConfigDir');
  logger.info('vupTempDir $vupTempDir');
  logger.info('vupDataDir $vupDataDir');

  Hive.init(join(vupConfigDir, 'hive'));

  Hive.registerAdapter(SyncTaskAdapter());
  Hive.registerAdapter(SyncModeAdapter());

  dataBox = await Hive.openBox('data');

  mySky.setup(dataBox.get('cookie') ?? '');

  syncTasks = await Hive.openBox('syncTasks');

  syncTasksTimestamps = await Hive.openBox('syncTasksTimestamps');
  syncTasksLock = await Hive.openBox('syncTasksLock');

  localFiles = await Hive.openBox('localFiles');

/*   await playlistService.init();
  await quotaService.init(); */
  cacheService.init(tempDirPath: vupTempDir);

  storageService = StorageService(
    mySky,
    isRunningInFlutterMode: isRunningInFlutterMode,
    syncTasks: syncTasks,
    temporaryDirectory: vupTempDir,
    dataDirectory: vupDataDir,
    localFiles: localFiles,
  );
}
