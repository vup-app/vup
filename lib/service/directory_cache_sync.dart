
import 'package:filesystem_dac/cache/base.dart';
import 'package:hive/hive.dart';
import 'package:vup/library/state.dart';
import 'package:vup/service/base.dart';

// TODO Implement, but without compression

class DirectoryCacheSyncService extends VupService with CustomState {
  late final DirectoryMetadataCache directoryIndexCache;
  late final String deviceId;
  late final Box<dynamic> directoryCacheSyncServiceData;

  final indexPath = 'vup.hns/cache/directory_sync/devices.json';

  Future<void> init(String deviceId) async {
    /*  this.deviceId = deviceId;
    directoryIndexCache = storageService.dac.dirCache;
    directoryCacheSyncServiceData =
        await Hive.openBox('directoryCacheSyncServiceData');

    Future.delayed(Duration(seconds: 60)).then((value) {
      uploadDirIndexCache();
    });

    Stream.periodic(Duration(hours: 3)).listen((event) {
      uploadDirIndexCache();
    });

    Future.delayed(Duration(seconds: 30)).then((value) {
      syncCache();
    });

    Stream.periodic(Duration(minutes: 30)).listen((event) {
      syncCache();
    }); */
  }
/* 
  void syncCache() async {
    info('[sync] cache');
    final indexRes = await hiddenDB.getJSON(
      indexPath,
    );

    final data = indexRes.data ?? {'devices': {}};

    final localTs = directoryCacheSyncServiceData.get('sync_last_ts') ?? 0;
    final currentTS = DateTime.now().millisecondsSinceEpoch;

    for (final devId in data['devices'].keys) {
      verbose('[sync] processing $devId...');
      if (devId == deviceId) continue;
      final ts = data['devices'][devId];
      if (ts > localTs) {
        info('[sync] downloading from ${devId}');
        final res = await hiddenDB.getRawData(
          'vup.hns/cache/directory_sync/device_${devId}.json',
        );

        info('[sync] decompressing from ${devId}');
        try {
          final Map<String, dynamic> remoteCache = json.decode(
            utf8.decode(await compute(
              lzma.decode,
              res.data!,
            )),
          );

          info('[sync] importing from ${devId} (${remoteCache.length} keys)');

          for (final key in remoteCache.keys) {
            if (key.length == 64) continue;
            final le = directoryIndexCache.get(key);
            if (le == null || le.revision < remoteCache[key]['r']) {
              directoryIndexCache.put(
                key,
                CachedEntry(
                  revision: remoteCache[key]['r'],
                  data: remoteCache[key]['d'],
                  skylink: remoteCache[key]['s'],
                ),
              );
            }
          }
        } catch (e, st) {
          error('$e $st');
        }
      }
    }

    directoryCacheSyncServiceData.put('sync_last_ts', currentTS);
    info('[sync] Done.');
  }

  void uploadDirIndexCache() async {
    info('[upload] compressing local cache...');

    await directoryIndexCache.compact();

    for (final String key in directoryIndexCache.keys) {
      if (key.length == 64) {
        directoryIndexCache.delete(key);
      }
    }

    final path = 'vup.hns/cache/directory_sync/device_${deviceId}.json';

    final compressed = await compute(
      lzma.encode,
      utf8.encode(
        json.encode(
          directoryIndexCache.toMap(),
        ),
      ),
    );

    final length = compressed.length;

    if (directoryCacheSyncServiceData.get('upload_last_compressed_length') ==
        length) {
      info('[upload] skipping because no local changes');
      return;
    }

    verbose('[upload] compressed size: ${filesize(length)}');

    info('[upload] Uploading compressed data...');

    await storageService.dac.mySkyProvider.setRawDataEncrypted(
      path,
      Uint8List.fromList(compressed),
      (DateTime.now().millisecondsSinceEpoch / 1000).round(),
    );
    info('[upload] Done!');

    info('[upload] Updating device index...');

    final indexRes = await storageService.dac.mySkyProvider.getJSONEncrypted(
      indexPath,
    );

    final data = indexRes.data ?? {'devices': {}};

    data['devices'][deviceId] = DateTime.now().millisecondsSinceEpoch;

    await storageService.dac.mySkyProvider.setJSONEncrypted(
      indexPath,
      data,
      indexRes.revision + 1,
    );

    info('[upload] Done.');

    directoryCacheSyncServiceData.put(
      'upload_last_compressed_length',
      length,
    );
  } */
}
