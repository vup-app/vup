import 'dart:convert';

import 'package:filesize/filesize.dart';
import 'package:hive/hive.dart';
import 'package:lib5/lib5.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/library/state.dart';
import 'package:vup/service/base.dart';

class QuotaService extends VupService with CustomState {
  int usedBytes = 0;
  int totalBytes = 0;

  late Box<Map> historyBox;

  String tooltip = '';

  Future<void> init() async {
    historyBox = await Hive.openBox('stats_history');
  }

  int counter = 0;

  void clear() {
    // totalBytes = -1;
    tooltip = '';
    $();
  }

  final portalStats = <String, Map>{};

  void update() async {
    verbose('update');

    for (final pc in mySky.storageServiceConfigs) {
      try {
        final res = await mySky.httpClient.get(
          pc.getAccountsAPIUrl(
            '/s5/account/stats',
          ),
          headers: pc.headers,
        );
        final stats = json.decode(res.body);

        portalStats[pc.authority] = stats;

        verbose('stats ${pc.authority} $stats');
      } catch (e, st) {
        logger.verbose('quota $e $st');
      }
    }

    if (mySky.api.storageServiceConfigs.isNotEmpty) {
      final uc = mySky.api.storageServiceConfigs.first;
      final primaryPortalStats = portalStats[uc.authority];
      try {
        usedBytes = primaryPortalStats!['stats']['total']['usedStorage'];

        final tier = primaryPortalStats['tier'];

        totalBytes = tier['storageLimit'];

        tooltip = '';
        tooltip +=
            'Primary upload portal: ${uc.authority}\nCurrent tier: ${tier['name']}\nUpload speed: ${filesize(tier['uploadBandwidth'])}/s';
      } catch (_) {}
    }
    $();
  }

  Future<void> refreshAuthCookie() async {
    return;
    /* info('refreshAuthCookie');
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
    ); */
  }
}
