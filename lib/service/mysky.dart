import 'dart:math';

import 'package:random_string/random_string.dart';
import 'package:simple_observable/simple_observable.dart';
import 'package:skynet/dacs.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/service/base.dart';

class MySkyService extends VupService {
  late SkynetClient skynetClient;

  void setup(String cookie) {
    skynetClient = SkynetClient(
      cookie: cookie,
      portal: currentPortalHost,
    );
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
      storageService.dac.onUserLogin();
      isLoggedIn.value = true;
      registerDeviceId();
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
  }

  Future<void> init() async {
    info('Using portal ${skynetClient.portalHost}');

    profileDAC = ProfileDAC(skynetClient);

    await autoLogin();
  }

  Future<void> storeSeedPhrase(String seed) async {
    await dataBox.put('seed', seed);
  }

  Future<String?> loadSeedPhrase() async {
    return dataBox.get('seed');
  }
}
