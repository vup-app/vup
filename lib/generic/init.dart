import 'dart:io';

import 'package:filesystem_dac/cache/hive.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/model/sync_task.dart';
import 'package:vup/service/notification/provider/apprise.dart';
import 'package:vup/service/storage.dart';
import 'package:vup/utils/device_info/docker.dart';
import 'package:vup/utils/external_ip/docker.dart';
import 'package:vup/utils/ffmpeg/io.dart';
import 'package:xdg_directories/xdg_directories.dart';

Future<void> initAppGeneric({required bool isRunningInFlutterMode}) async {
  final tempDir = Directory('/tmp');

  vupTempDir = join(tempDir.path, 'vup');

  vupConfigDir = '/config';
  vupDataDir = '/data';

  await logger.init(vupTempDir);

  logger.info('vupConfigDir $vupConfigDir');
  logger.info('vupTempDir $vupTempDir');
  logger.info('vupDataDir $vupDataDir');

  ffMpegProvider = IOFFmpegProvider();
  notificationProvider = AppriseNotificationProvider();
  externalIpAddressProvider = DockerExternalIpAddressProvider();
  deviceInfoProvider = DockerDeviceInfoProvider();

  Hive.init(join(vupConfigDir, 'hive'));

  Hive.registerAdapter(SyncTaskAdapter());
  Hive.registerAdapter(SyncModeAdapter());

  dataBox = await Hive.openBox('data');

  await mySky.setup();

  syncTasks = await Hive.openBox('syncTasks');

  syncTasksTimestamps = await Hive.openBox('syncTasksTimestamps');
  syncTasksLock = await Hive.openBox('syncTasksLock');

  localFiles = HiveKeyValueDB(await Hive.openBox('localFiles'));

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
