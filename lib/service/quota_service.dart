import 'package:filesize/filesize.dart';
import 'package:hive/hive.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/library/state.dart';
import 'package:vup/service/base.dart';
import 'package:skynet/src/portal_accounts/index.dart';

class QuotaService extends VupService with CustomState {
  int usedBytes = 0;
  int totalBytes = 0;
  late Box<Map> historyBox;

  String tooltip = '';

  Future<void> init() async {
    historyBox = await Hive.openBox('stats_history');

    Stream.periodic(Duration(minutes: 9)).listen((event) {
      _unpinDeletedSkylinks();
    });

    Future.delayed(Duration(minutes: 2)).then((value) {
      refreshAuthCookie();
    });
  }

  void _unpinDeletedSkylinks() async {
    info('_unpinDeletedSkylinks');
    for (final key in storageService.dac.deletedSkylinks.keys.toList()) {
      String skylink = storageService.dac.deletedSkylinks.get(key) as String;
      if (skylink.startsWith('sia://')) {
        skylink = skylink.substring(6);
      }

      if (skylink.length == 46) {
        verbose('unpin $skylink');
        await mySky.skynetClient.portalAccount.unpinSkylink(skylink);
        storageService.dac.deletedSkylinks.delete(key);
      }
    }
  }

  int counter = 0;

  void clear() {
    totalBytes = -1;
    tooltip = '';
    $();
  }

  void update() async {
    verbose('update');
    try {
      final stats =
          await storageService.mySkyProvider.client.portalAccount.getStats();
      verbose('stats $stats');
      if (stats['totalUploadsSize'] == null) {
        totalBytes = -1;
        $();
        return;
      }
      final userInfo =
          await storageService.mySkyProvider.client.portalAccount.getUserInfo();

      final limits =
          await storageService.mySkyProvider.client.portalAccount.getLimits();

      final tier = limits['userLimits'][userInfo['tier']];

      tooltip = '$tier\n$stats\n$userInfo';

      tooltip = '';
      tooltip +=
          'Portal: ${mySky.skynetClient.portalHost}\nCurrent tier: ${tier['tierName']}\nSpeeds: ${filesize(tier['uploadBandwidth'])}/s upload, ${filesize(tier['downloadBandwidth'])}/s download\n';
      tooltip += 'Max upload size: ${filesize(tier['maxUploadSize'])}';

      usedBytes = stats['totalUploadsSize'];
      totalBytes = tier['storageLimit'] ?? 0;

      $();
      counter++;
      if (counter >= 10) {
        counter = 0;
        historyBox.put(
            (DateTime.now().millisecondsSinceEpoch / 1000).round(), stats);
      }
    } catch (e, st) {
      print('quota $e $st');
    }
  }

  Future<void> refreshAuthCookie() async {
    info('refreshAuthCookie');
    final portalAccounts = dataBox.get('mysky_portal_auth_accounts');
    final currentPortalAccounts = portalAccounts[mySky.skynetClient.portalHost];
    final portalAccountTweak = currentPortalAccounts['accountNicknames']
        [currentPortalAccounts['activeAccountNickname']];

    final jwt = await login(
      mySky.skynetClient,
      mySky.user.rawSeed,
      portalAccountTweak,
    );
    mySky.skynetClient.headers = {'cookie': jwt};
    dataBox.put('cookie', jwt);

    dataBox.put(
      'mysky_portal_auth_ts',
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
