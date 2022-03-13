import 'dart:io';

import 'package:filesize/filesize.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/service/base.dart';

class CacheService extends VupService {
  late final Directory tempDir;

  double get macCacheSizeInGB => dataBox.get('cache_max_size') ?? 1;

  void init({required String tempDirPath}) {
    tempDir = Directory(tempDirPath);
    runGarbageCollector();
    Stream.periodic(Duration(minutes: 15)).listen((event) {
      runGarbageCollector();
    });
  }

  Future<void> runGarbageCollector(/* {Duration? cacheLimitDuration} */) async {
    info('> runGarbageCollector');
    final clt = DateTime.now().subtract(Duration(hours: 24));

    final allCacheFiles = await tempDir.list(recursive: true).toList();

    allCacheFiles.removeWhere((element) => element is! File);

    int totalSize = allCacheFiles.fold(
      0,
      (previousValue, element) =>
          previousValue + (element as File).lengthSync(),
    );
    verbose('total used cache size: ${filesize(totalSize)}');

    final maxCacheSize = (macCacheSizeInGB * 1000 * 1000 * 1000).round();

    if (totalSize < maxCacheSize) {
      info('skipping because max cache size is not reached yet');
      return;
    }

    allCacheFiles
        .sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));

    while (totalSize > maxCacheSize) {
      if (allCacheFiles.isEmpty) {
        break;
      }
      final File file = allCacheFiles.removeAt(0) as File;
      if (file.path.contains('encrypted_files')) {
        if (file.statSync().modified.isAfter(clt)) {
          continue;
        }
      }
      totalSize -= file.lengthSync();
      verbose('delete ${file.path}');
      await file.delete();
    }

    /*  await for (final entity in ) {
      if (entity is! File) continue;
      // info(entity);
      final stat = await entity.stat();
      if (stat.modified.isBefore(clt)) {
        await entity.delete();
      } */
    // info(stat.accessed);

    // info(stat.modified);
    /* } */
  }

  Future<int> calculateUsedCacheSize() async {
    int totalLength = 0;
    await for (final entity in tempDir.list(recursive: true)) {
      if (entity is File) {
        totalLength += entity.lengthSync();
      }
    }
    return totalLength;
  }
}
