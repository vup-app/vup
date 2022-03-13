import 'dart:convert';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:hive_crdt/hive_adapters.dart';
import 'package:hive_crdt/hive_crdt.dart';
import 'package:pool/pool.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/service/base.dart';

class ActivityService extends VupService {
  // final Map<String, int> playPositions = {};
  // final Map<String, int> playCounts = {};
  late final HiveCrdt<String, int> playPositions;
  late final HiveCrdt<String, int> playCounts;
  late final HiveCrdt<String, int> lastPlayedDates;

  final syncPool = Pool(1);

  Future<void> init(String deviceId) async {
    Hive.registerAdapter(HlcAdapter<String>(42));
    Hive.registerAdapter(RecordAdapter<int>(43));

    playPositions =
        await HiveCrdt.open<String, int>('play_positions', deviceId);

    playCounts = await HiveCrdt.open<String, int>('play_counts', deviceId);

    lastPlayedDates =
        await HiveCrdt.open<String, int>('last_played_dates', deviceId);

    /* playPositions = await Hive.openBox('play_positions');
    playCounts = await Hive.openBox('play_counts');
    lastPlayedDates = await Hive.openBox('last_played_dates'); */
    // print(lastPlayedDates.toMap());
    syncPool.withResource(() => syncAll());

    Stream.periodic(Duration(hours: 1)).listen((event) {
      syncPool.withResource(() => syncAll());
    });
  }

  DateTime lastSync = DateTime(2000);

  bool isWaiting = false;

  Future<void> syncAll() async {
    final diff = lastSync
        .difference(
          DateTime.now(),
        )
        .abs();

    // info('> syncAll diff: $diff');
    final minDur = Duration(minutes: 5);
    if (diff < minDur) {
      if (isWaiting) return;
      isWaiting = true;
      Future.delayed(minDur - diff).then((value) {
        syncPool.withResource(() => syncAll());
      });
      return;
    }
    isWaiting = false;
    info('> syncAll');

    await syncCrdt('playPositions', playPositions);
    await syncCrdt('playCounts', playCounts);
    await syncCrdt('lastPlayedDates', lastPlayedDates);
    lastSync = DateTime.now();
    info('< syncAll');
  }

  // Future<void> syncDeviceIds{}

  // Map<Hlc> lastSyncTimes = {};

  Future<void> syncCrdt(String key, HiveCrdt<String, int> crdt) async {
    info('> syncCrdt $key');
    /* final hlc = crdt.canonicalTime;
    crdt.put('c', 3); */
    final path = 'vup.hns/activity/crdt/$key.json';

    final res = await storageService.dac.mySkyProvider.getRawDataEncrypted(
      path,
    );
    final remoteString = res.data == null ? null : utf8.decode(res.data!);

    // verbose('syncCrdt $key remote data length: ${remoteString}');

    if (remoteString != null) {
      crdt.mergeJson(remoteString);
    }

    final jsonString = crdt.toJson(/* modifiedSince: hlc */);

    if (jsonString == remoteString) {
      info('< syncCrdt skip $key (no changes)');
      return;
    }
    // verbose('set $jsonString');

    await storageService.dac.mySkyProvider.setRawDataEncrypted(
      path,
      Uint8List.fromList(utf8.encode(jsonString)),
      res.revision + 1,
    );
    info('< syncCrdt $key');
  }

  void triggerSync() {
    verbose('triggerSync');
    if (!isWaiting) {
      syncPool.withResource(() => syncAll());
    }
  }

  int getPlayCount(String hash) {
    return playCounts.get(hash) ?? 0;
  }

  void setPlayPosition(String hash, int position) {
    info('setPlayPosition $hash $position');
    playPositions.put(hash, position);
    lastPlayedDates.put(hash, DateTime.now().millisecondsSinceEpoch);

    triggerSync();
  }

  int getPlayPosition(String hash) {
    // print('getPlayPosition $hash ${playPositions.get(hash) ?? 0}');
    return playPositions.get(hash) ?? 0;
  }

  void logPlayEvent(String hash /* , {DateTime? ts} */) async {
    info('logPlayEvent $hash');
    playCounts.put(hash, getPlayCount(hash) + 1);
    lastPlayedDates.put(hash, DateTime.now().millisecondsSinceEpoch);
    setPlayPosition(hash, 0);

    // TODO Add to activity list
  }

  DateTime getLastPlayedDate(String? itemId) {
    return DateTime.fromMillisecondsSinceEpoch(
      itemId == null ? 0 : lastPlayedDates.get(itemId) ?? 0,
    );
  }
}
