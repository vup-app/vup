import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import 'package:random_string/random_string.dart';
import 'package:s5_server/api.dart';

import 'package:simple_observable/simple_observable.dart';
import 'package:stash_hive/stash_hive.dart';
import 'package:stash/stash_api.dart';
import 'package:vup/app.dart';
import 'package:lib5/storage_service.dart';
import 'package:lib5/util.dart';
import 'package:vup/service/base.dart';
import 'package:http/http.dart' as http;

class MySkyService extends VupService {
  late final CryptoImplementation crypto;
  late S5APIProviderWithRemoteUpload api;

  late S5UserIdentity identity;

  final httpClient = http.Client();

  final portalAccountsPath = 'storage-service-accounts.json';

  final useSecureStorage = false;

  List<StorageServiceConfig> storageServiceConfigs = [];

  late final Box<Uint8List> deletedCIDs;

  Future<void> setup() async {
    final dbDir = Directory(join(
      vupDataDir,
      'stash',
    ));
    dbDir.createSync(recursive: true);

    deletedCIDs = await Hive.openBox<Uint8List>(
      's5-deleted-cids',
    );

    api = S5NodeAPIProviderWithRemoteUpload(s5Node, deletedCIDs: deletedCIDs);
  }

  late Map portalAccounts;

  Future<void> loadPortalAccounts() async {
    final res = await hiddenDB.getJSON(
      portalAccountsPath,
    );

    portalAccounts = res.data;

    dataBox.put(
      'portal_accounts',
      json.encode(res.data),
    );
    dataBox.put(
      'portal_accounts_revision',
      res.revision,
    );
    await ensureAllEnabledPortalsHaveAuthTokens();
    setupPortalAccounts();
  }

  Future<void> ensureAllEnabledPortalsHaveAuthTokens() async {
    final enabledPortals = portalAccounts['enabledPortals'];
    for (final ep in enabledPortals) {
      final authToken = dataBox.get('portal_${ep}_auth_token');

      if (authToken == null) {
        try {
          final portal = portalAccounts['portals'][ep]!;

          final pc = StorageServiceConfig(
            scheme: portal['protocol'],
            authority: ep,
            headers: {'user-agent': vupUserAgent},
          );
          final seed = base64UrlNoPaddingDecode(
            portal['accounts'][portal['activeAccount']]['seed'],
          );

          final res = await login(
            serviceConfig: pc,
            httpClient: httpClient,
            identity: identity,
            seed: seed,
            label: 'vup-${dataBox.get('deviceId')}',
          );

          await dataBox.put('portal_${ep}_auth_token', res);
        } catch (e, st) {
          logger.verbose(e);
          logger.verbose(st);
        }
      }
    }
  }

  Future<void> savePortalAccounts() async {
    await hiddenDB.setJSON(
      portalAccountsPath,
      portalAccounts,
      revision: (dataBox.get(
                'portal_accounts_revision',
              ) ??
              0) +
          1,
    );

    await loadPortalAccounts();
  }

  void setupPortalAccounts() {
    if (!dataBox.containsKey('portal_accounts')) {
      return;
    }
    logger.verbose('setupPortalAccounts');
    portalAccounts = json.decode(dataBox.get('portal_accounts'));
    final uploadPortalOrder = portalAccounts['uploadPortalOrder'];

    api.storageServiceConfigs.clear();

    for (final u in uploadPortalOrder) {
      logger.verbose('setupPortalAccounts1 $u');
      final portal = portalAccounts['portals'][u]!;
      final authToken = dataBox.get('portal_${u}_auth_token');

      if (authToken == null) {
        // TODO Throw error
        continue;
      }
      logger.verbose('setupPortalAccounts2 $u');

      final pc = StorageServiceConfig(
        scheme: portal['protocol'],
        authority: u,
        headers: {
          'authorization': 'Bearer $authToken',
          'user-agent': vupUserAgent,
        },
      );

      storageServiceConfigs.add(pc);

      api.storageServiceConfigs.add(pc);
    }
    logger.verbose('setupPortalAccounts done');

    for (final uc in storageServiceConfigs) {
      connectToPortalNodes(uc);
    }
  }

  void connectToPortalNodes(StorageServiceConfig pc) async {
    try {
      final res = await httpClient.get(
        Uri.parse(
          '${pc.scheme}://${pc.authority}/s5/p2p/nodes',
        ),
      );
      final data = json.decode(res.body);
      for (final node in data['nodes']) {
        final id = NodeID.decode(node['id']);
        final uris = <Uri>[];
        for (final uri in node['uris']) {
          uris.add(Uri.parse(uri).replace(userInfo: id.toBase58()));
        }
        if (uris.isNotEmpty) {
          if (!s5Node.p2p.reconnectDelay.containsKey(id)) {
            s5Node.p2p.connectToNode(uris);
          }
        }
      }
    } catch (e, st) {
      warning(e);
      verbose(st);
    }
  }

  // late ProfileDAC profileDAC;

  final isLoggedIn = Observable<bool?>(initialValue: null);

  Future<void> autoLogin() async {
    info('autoLogin');
    final authPayload = await loadAuthPayload();

    if (authPayload != null) {
      info('autoLogin done');
      setupPortalAccounts();

      identity = S5UserIdentity.unpack(
        base64UrlNoPaddingDecode(authPayload),
        api: api,
      );

      hiddenDB = identity.hiddenDB;

      // storageService.mySkyProvider.isLoggedIn = true;
      // await storageService.mySkyProvider.load('vup.hns');

      await storageService.onAuth();

      // TODO Maybe not await
      await storageService.dac.onUserLogin();
      await storageService.dac.getDirectoryMetadata('');

      isLoggedIn.value = true;
      registerDeviceId();

      Future.delayed(const Duration(seconds: 30)).then((value) {
        updateDeviceList();
      });
      await directoryCacheSyncService.init(dataBox.get('deviceId'));
      await activityService.init(dataBox.get('deviceId'));
      await playlistService.init();
      await quotaService.init();
      sidebarService.init();

      quotaService.update();

      Stream.periodic(Duration(seconds: 60)).listen((event) {
        quotaService.update();
      });

      pinningService.start();
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

  final deviceIndexPath = 'vup.hns/devices/index.json';

  Future<Map> fetchDeviceList() async {
    final res = await hiddenDB.getJSON(
      deviceIndexPath,
    );

    return res.data ?? {'devices': {}};
  }

  void updateDeviceList() async {
    info('updateDeviceList');
    final res = await hiddenDB.getJSON(
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

      await hiddenDB.setJSON(
        deviceIndexPath,
        data,
        revision: res.revision + 1,
      );

      info('added device to index.');
    }
  }

  late FlutterSecureStorage secureStorage;

  Future<void> init() async {
    // info('Using portal ${skynetClient.portalHost}');

    secureStorage = const FlutterSecureStorage();

/*     if (!Platform.isMacOS && useSecureStorage) {
      if (dataBox.containsKey('seed')) {
        await secureStorage.write(key: 'seed', value: dataBox.get('seed'));
        await dataBox.delete('seed');
      }
    } */

    // profileDAC = ProfileDAC(skynetClient);

    await autoLogin();
  }

  Future<void> storeAuthPayload(String authPayload) async {
    if (!Platform.isMacOS && useSecureStorage) {
      await secureStorage.write(key: 'auth_payload', value: authPayload);
    } else {
      await dataBox.put('auth_payload', authPayload);
    }
  }

  Future<String?> loadAuthPayload() async {
    if (!Platform.isMacOS && useSecureStorage) {
      return secureStorage.read(key: 'auth_payload');
    } else {
      return dataBox.get('auth_payload');
    }
  }
}
