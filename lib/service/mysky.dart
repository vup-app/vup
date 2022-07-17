import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import 'package:random_string/random_string.dart';
import 'package:simple_observable/simple_observable.dart';
import 'package:skynet/dacs.dart';
import 'package:stash_hive/stash_hive.dart';
import 'package:stash/stash_api.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/service/base.dart';

class MySkyService extends VupService {
  late SkynetClient skynetClient;

  final portalAccountsPath = 'skynet-mysky.hns/portal-accounts.json';

  late final Vault<String> usedMySkyPathsVault;

  void setup(String cookie) {
    final dbDir = Directory(join(
      vupDataDir,
      'stash',
    ));
    dbDir.createSync(recursive: true);

    final hiveStore = newHiveDefaultVaultStore(path: dbDir.path);

    usedMySkyPathsVault = hiveStore.vault<String>(
      name: 'mysky_used_paths',
    );

    skynetClient = SkynetClient(
      cookie: cookie,
      portal: currentPortalHost,
      usedMySkyPathsVault: usedMySkyPathsVault,
    );
    skynetClient.headers ??= {};
    skynetClient.headers!['user-agent'] = vupUserAgent;
  }

  late ProfileDAC profileDAC;

  late SkynetUser user;

  final isLoggedIn = Observable<bool?>(initialValue: null);

  Future<void> autoLogin() async {
    info('autoLogin');
    final value = await loadSeedPhrase();

    if (value != null) {
      info('autoLogin done');
      user = await SkynetUser.fromMySkySeedPhrase(value);

      storageService.mySkyProvider.skynetUser = user;
      storageService.mySkyProvider.isLoggedIn = true;
      storageService.dac.onUserLogin();
      isLoggedIn.value = true;
      registerDeviceId();
      await directoryCacheSyncService.init(dataBox.get('deviceId'));
      await activityService.init(dataBox.get('deviceId'));
      await playlistService.init();
      await quotaService.init();
      sidebarService.init();
    }
  }

  void registerDeviceId() {
    if (!dataBox.containsKey('deviceId')) {
      final newDeviceId = randomAlphaNumeric(
        8,
        provider: CoreRandomProvider.from(
          Random.secure(),
        ),
      );
      info('registerDeviceId $newDeviceId');

      dataBox.put('deviceId', newDeviceId);
    }
    Future.delayed(Duration(seconds: 50)).then((value) {
      updateDeviceList();
    });
  }

  final deviceIndexPath = 'vup.hns/devices/index.json';

  Future<Map> fetchDeviceList() async {
    final res = await storageService.dac.mySkyProvider.getJSONEncrypted(
      deviceIndexPath,
    );

    return res.data ?? {'devices': {}};
  }

  void updateDeviceList() async {
    info('updateDeviceList');
    final res = await storageService.dac.mySkyProvider.getJSONEncrypted(
      deviceIndexPath,
    );

    final deviceId = dataBox.get('deviceId');

    final data = res.data ?? {'devices': {}};

    if (data['devices'][deviceId] == null) {
      info('adding this device...');
      final map = await deviceInfoProvider.load();

      data['devices'][deviceId] = {
        'created': DateTime.now().millisecondsSinceEpoch,
        'info': map,
      };

      await storageService.dac.mySkyProvider.setJSONEncrypted(
        deviceIndexPath,
        data,
        res.revision + 1,
      );

      info('added device to index.');
    }
  }

  late FlutterSecureStorage secureStorage;

  Future<void> init() async {
    info('Using portal ${skynetClient.portalHost}');

    secureStorage = const FlutterSecureStorage();

    if (dataBox.containsKey('seed')) {
      await secureStorage.write(key: 'seed', value: dataBox.get('seed'));
      await dataBox.delete('seed');
    }

    profileDAC = ProfileDAC(skynetClient);

    await autoLogin();
  }

  Future<void> storeSeedPhrase(String seed) async {
    await secureStorage.write(key: 'seed', value: seed);
  }

  Future<String?> loadSeedPhrase() async {
    return secureStorage.read(key: 'seed');
  }

  void dumpUsedMySkyPathsVault() {
    mySky.usedMySkyPathsVault.keys.then((value) async {
      final list = <String>[];
      for (final key in value) {
        final path = await mySky.usedMySkyPathsVault.get(key);
        if (path != null) list.add(path);
      }
      verbose('[dumpUsedMySkyPathsVault] ${json.encode(list)}');
    });
  }
}
