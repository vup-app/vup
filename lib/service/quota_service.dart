import 'dart:convert';

import 'package:filesize/filesize.dart';
import 'package:hive/hive.dart';
import 'package:lib5/lib5.dart';
import 'package:s5_server/store/base.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/library/state.dart';
import 'package:vup/service/base.dart';

class QuotaService extends VupService with CustomState {
  // late Box<Map> historyBox;

  // String tooltip = '';

  Future<void> init() async {
    // historyBox = await Hive.openBox('stats_history');
  }

  int counter = 0;

  void clear() {
    // totalBytes = -1;
    // tooltip = '';
    $();
  }

  final accountInfos = <String, AccountInfo>{};

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

        final int usedStorage = stats['stats']['total']['usedStorage'];
        final int totalStorage = stats['tier']['storageLimit'];
        final bool isRestricted = stats['isRestricted'] == true;

        accountInfos[pc.authority] = AccountInfo(
          serviceName: pc.authority,
          usedStorageBytes: usedStorage,
          totalStorageBytes: totalStorage,
          isRestricted: isRestricted,
          userIdentifier: stats['email'],
          subscription: stats['tier']['name'],
        );

        // verbose('stats ${pc.authority} $stats');
      } catch (e, st) {
        logger.verbose('quota $e $st');
      }
    }
    if (s5Node.store != null) {
      accountInfos['_local'] = await s5Node.store!.getAccountInfo();
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
