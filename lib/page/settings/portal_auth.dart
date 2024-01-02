import 'dart:convert';

import 'package:clipboard/clipboard.dart';
import 'package:filesize/filesize.dart';
import 'package:s5_server/store/create.dart';
import 'package:selectable_autolink_text/selectable_autolink_text.dart';
import 'package:simple_observable/simple_observable.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:vup/app.dart';
import 'package:lib5/util.dart';
import 'package:lib5/storage_service.dart';

import 'package:vup/view/sidebar.dart';

class PortalAuthSettingsPage extends StatefulWidget {
  const PortalAuthSettingsPage({Key? key}) : super(key: key);

  @override
  _PortalAuthSettingsPageState createState() => _PortalAuthSettingsPageState();
}

class _PortalAuthSettingsPageState extends State<PortalAuthSettingsPage> {
/*   final ctrl = TextEditingController(
    text: dataBox.get('cookie') ?? '',
  );
  final authEmailCtrl = TextEditingController(
    text: dataBox.get('auth_email') ?? '',
  ); */

/*   void saveCookie(String cookie) {
    ctrl.text = cookie;
    dataBox.put('cookie', cookie);
  }
 */

  String? get localStoreName =>
      mySky.portalAccounts['_local']?['store']?.keys.first;

  final hasChanges = Observable(initialValue: false);

  void updateQuota() {
    quotaService.update().then((value) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        /* StreamBuilder(
          stream: quotaService.stream,
          builder: (context, snapshot) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(quotaService.tooltip),
            );
          },
        ), */

        for (final p in mySky.portalAccounts['portals'].keys)
          _buildPortalCard(p, context),

        if (localStoreName != null) _buildLocalStoreCard(context),
        /*   TextField(
          decoration: InputDecoration(
            labelText: 'Portal Host',
          ),
          controller: TextEditingController(text: currentPortalHost),
          onChanged: (str) {
            dataBox.put('portal_host', str);
          },
        ),
        SizedBox(
          height: 16,
        ),
        TextField(
          decoration: InputDecoration(
            labelText: 'E-Mail',
          ),
          controller: authEmailCtrl,
          onChanged: (str) {
            dataBox.put('auth_email', str);
          },
        ),
        SizedBox(
          height: 16,
        ),
        ElevatedButton(
          onPressed: () async {
            showLoadingDialog(context, 'Signing up...');
            try {
              // await storageService.mySkyProvider.client.portalHost
              final jwt = await register(
                storageService.mySkyProvider.client,
                storageService.mySky.user.rawSeed,
                authEmailCtrl.text,
              );
              saveCookie(jwt);
              context.pop();
            } catch (e, st) {
              context.pop();
              showErrorDialog(context, e, st);
            }
          },
          child: Text(
            'Register',
          ),
        ),
        SizedBox(
          height: 16,
        ),
        ElevatedButton(
          onPressed: () async {
            showLoadingDialog(context, 'Logging in...');
            try {
              final jwt = await login(
                storageService.mySkyProvider.client,
                storageService.mySky.user.rawSeed,
                authEmailCtrl.text,
              );
              saveCookie(jwt);
              context.pop();
            } catch (e, st) {
              context.pop();
              showErrorDialog(context, e, st);
            }
          },
          child: Text(
            'Login',
          ),
        ),  */ //
        const SizedBox(
          height: 8,
        ),
/*         if ((dataBox.get('mysky_portal_auth_ts') ?? 0) != 0) ...[
          SizedBox(
            height: 12,
          ),
          Text(
            'Last auto-login time: ${DateTime.fromMillisecondsSinceEpoch(dataBox.get('mysky_portal_auth_ts'))}',
          ),
          SizedBox(
            height: 12,
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                showLoadingDialog(context, 'Logging in using MySky...');
                await quotaService.refreshAuthCookie();
                context.pop();
              } catch (e, st) {
                context.pop();
                showErrorDialog(context, e, st);
              }
              setState(() {});
            },
            child: Text(
              'Auto-refresh auth cookie',
            ),
          ),
        ], */
        /*   if ((dataBox.get('mysky_portal_auth_ts') ?? 0) == 0 &&
            (dataBox.get('cookie') ?? '').isNotEmpty) ...[
          SizedBox(
            height: 12,
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                showLoadingDialog(context,
                    'Setting up Login-with-MySky for your portal account...');

                final portalAccountsRes =
                    await storageService.mySkyProvider.getJSONEncrypted(
                  mySky.portalAccountsPath,
                );
                ;
                final portalAccounts = portalAccountsRes.data ?? {};

                if (!portalAccounts
                    .containsKey(mySky.skynetClient.portalHost)) {
                  final tweak = randomAlphaNumeric(
                    64,
                    provider: CoreRandomProvider.from(
                      Random.secure(),
                    ),
                  );

                  portalAccounts[mySky.skynetClient.portalHost] = {
                    'activeAccountNickname': 'vup',
                    'accountNicknames': {
                      'vup': tweak,
                    }
                  };
                  await registerUserPubkey(
                    mySky.skynetClient,
                    mySky.user.rawSeed,
                    tweak,
                  );
                  await storageService.mySkyProvider.setJSONEncrypted(
                    mySky.portalAccountsPath,
                    portalAccounts,
                    portalAccountsRes.revision + 1,
                  );
                }
                final currentPortalAccounts =
                    portalAccounts[mySky.skynetClient.portalHost];

                final portalAccountTweak =
                    currentPortalAccounts['accountNicknames']
                        [currentPortalAccounts['activeAccountNickname']];

                final jwt = await login(
                  mySky.skynetClient,
                  mySky.user.rawSeed,
                  portalAccountTweak,
                );

                mySky.skynetClient.headers = {
                  'cookie': jwt,
                  'user-agent': vupUserAgent,
                };

                dataBox.put('cookie', jwt);

                dataBox.put('mysky_portal_auth_accounts', portalAccounts);
                dataBox.put(
                  'mysky_portal_auth_ts',
                  DateTime.now().millisecondsSinceEpoch,
                );

                context.pop();
              } catch (e, st) {
                context.pop();
                showErrorDialog(context, e, st);
              }
              setState(() {});
            },
            child: Text(
              'Setup Login-with-MySky for portal account',
            ),
          ),
        ], */
        /*   SizedBox(
          height: 12,
        ), */
        Row(
          children: [
            ElevatedButton(
              onPressed: () async {
                try {
                  showLoadingDialog(context, 'Loading...');

                  await mySky.loadPortalAccounts();

                  context.pop();
                  setState(() {});
                  updateQuota();
                } catch (e, st) {
                  context.pop();
                  showErrorDialog(context, e, st);
                }
              },
              child: Text(
                'Reload Accounts',
              ),
            ),
            SizedBox(
              width: 16,
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  showLoadingDialog(context, 'Saving...');

                  await mySky.savePortalAccounts();

                  context.pop();
                  setState(() {});
                  hasChanges.value = false;
                } catch (e, st) {
                  context.pop();
                  showErrorDialog(context, e, st);
                }
              },
              child: Text(
                'Save Configuration',
              ),
            ),
          ],
        ),
        SizedBox(
          height: 12,
        ),
        Text(
          'Add Storage Service',
          style: titleTextStyle,
        ),
        SizedBox(
          height: 8,
        ),
        Wrap(
          runSpacing: 10,
          children: [
            ElevatedButton(
              onPressed: () async {
                // final _emailCtrl = TextEditingController();
                final _portalCtrl = TextEditingController();
                final _authTokenCtrl = TextEditingController();

                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      'Register on S5 Node',
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            labelText: 'API URL',
                            hintText: 'https://example.com',
                          ),
                          autofocus: true,
                          controller: _portalCtrl,
                        ),
                        SizedBox(
                          height: 16,
                        ),
                        TextField(
                          decoration: InputDecoration(
                            labelText: 'Invite Code (optional)',
                          ),
                          controller: _authTokenCtrl,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          context.pop();
                        },
                        child: Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            showLoadingDialog(
                                context, 'Registering on S5 Node...');

                            final parts = _portalCtrl.text.split('://');

                            if (parts.length < 2) {
                              throw 'Invalid URL, needs protocol (https://)';
                            }
                            String authority = parts[1];
                            if (authority.endsWith('/')) {
                              authority =
                                  authority.substring(0, authority.length - 1);
                            }

                            final portalConfig = StorageServiceConfig(
                              authority: authority,
                              scheme: parts[0],
                              headers: {},
                            );

                            if (mySky.portalAccounts['portals']
                                .containsKey(portalConfig.authority)) {
                              throw 'You are already registered on this portal';
                            }

                            final seed =
                                storageService.crypto.generateRandomBytes(32);

                            final authToken = await register(
                              serviceConfig: portalConfig,
                              httpClient: mySky.httpClient,
                              identity: mySky.identity,
                              email: null,
                              seed: seed,
                              label: 'vup-${dataBox.get('deviceId')}',
                              authToken: _authTokenCtrl.text.isEmpty
                                  ? null
                                  : _authTokenCtrl.text,
                            );

                            mySky.portalAccounts['portals']
                                [portalConfig.authority] = {
                              'protocol': portalConfig.scheme,
                              'activeAccount': 'vup',
                              'accounts': {
                                'vup': {
                                  'seed': base64UrlNoPaddingEncode(seed),
                                }
                              }
                            };
                            setupServiceOrder(portalConfig.authority);

                            dataBox.put(
                              'portal_${portalConfig.authority}_auth_token',
                              authToken,
                            );

                            await mySky.savePortalAccounts();
                            context.pop();
                            context.pop();
                            setState(() {});

                            updateQuota();
                          } catch (e, st) {
                            context.pop();
                            showErrorDialog(context, e, st);
                          }
                        },
                        child: Text('Register'),
                      ),
                    ],
                  ),
                );
                /* await showPortalDialog(context);
                setState(() {}); */
              },
              child: Text(
                'Register on S5 Node',
              ),
            ),
            if (localStoreName == null) ...[
              SizedBox(
                width: 8,
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final apiKeyCtrl = TextEditingController();
                    final apiKeyRes = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Link Pixeldrain Account'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SelectableAutoLinkText(
                              'You can get your API Key on https://pixeldrain.com/user/api_keys',
                              onTap: (url) {
                                launchUrlString(url);
                              },
                              linkStyle: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            SizedBox(
                              height: 16,
                            ),
                            TextField(
                              controller: apiKeyCtrl,
                              decoration: InputDecoration(
                                labelText: 'API Key',
                                hintText:
                                    'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                              ),
                              autofocus: true,
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => context.pop(),
                            child: Text(
                              'Cancel',
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => context.pop(apiKeyCtrl.text),
                            child: Text(
                              'Link',
                            ),
                          ),
                        ],
                      ),
                    );
                    if (apiKeyRes != null) {
                      showLoadingDialog(context, 'Setting up Pixeldrain...');
                      final apiKey = apiKeyRes.trim() as String;
                      final res = await mySky.httpClient.get(
                        Uri.parse(
                          'https://pixeldrain.com/api/user/lists',
                        ),
                        headers: {
                          'Authorization':
                              "Basic ${base64Url.encode(utf8.encode(':$apiKey'))}"
                        },
                      );
                      res.expectStatusCode(200);
                      mySky.portalAccounts['_local'] = {
                        'store': {
                          'pixeldrain': {'apiKey': apiKey}
                        }
                      };

                      setupServiceOrder('_local');

                      await mySky.savePortalAccounts();

                      final stores = createStoresFromConfig(
                        mySky.portalAccounts['_local'],
                        httpClient: mySky.httpClient,
                        node: s5Node,
                      );
                      s5Node.store = stores.values.first;
                      // TODO Configurable
                      s5Node.exposeStore = true;
                      await s5Node.store!.init();

                      context.pop();
                      setState(() {});

                      updateQuota();
                    }
                  } catch (e, st) {
                    showErrorDialog(context, e, st);
                  }
                },
                child: Text(
                  'Link Pixeldrain Account',
                ),
              ),
              SizedBox(
                width: 8,
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final workerApiUrlCtrl = TextEditingController();
                    final apiPasswordCtrl = TextEditingController();
                    final downloadUrlCtrl = TextEditingController();
                    final dialogRes = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Add Sia Renter (renterd)'),
                        content: SizedBox(
                          width: 400,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SelectableAutoLinkText(
                                'To use this store, you need a fully configured instance of https://github.com/SiaFoundation/renterd running somewhere. You should also setup a reverse proxy for downloads. Documentation: https://docs.sfive.net/stores/sia.html',
                                onTap: (url) {
                                  launchUrlString(url);
                                },
                                linkStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                              SizedBox(
                                height: 16,
                              ),
                              TextField(
                                controller: workerApiUrlCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Worker API URL',
                                  hintText: 'http://localhost:9980/api/worker',
                                ),
                                autofocus: true,
                              ),
                              SizedBox(
                                height: 16,
                              ),
                              TextField(
                                controller: apiPasswordCtrl,
                                decoration: InputDecoration(
                                  labelText: 'API Password',
                                ),
                              ),
                              SizedBox(
                                height: 16,
                              ),
                              TextField(
                                controller: downloadUrlCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Download URL',
                                ),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => context.pop(),
                            child: Text(
                              'Cancel',
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => context.pop(true),
                            child: Text(
                              'Add',
                            ),
                          ),
                        ],
                      ),
                    );
                    if (dialogRes == true) {
                      showLoadingDialog(context, 'Adding Sia Store...');
                      String workerApiUrl = workerApiUrlCtrl.text;
                      if (workerApiUrl.endsWith('/')) {
                        workerApiUrl =
                            workerApiUrl.substring(0, workerApiUrl.length - 1);
                      }
                      if (Uri.parse(workerApiUrl).path.length < 3) {
                        workerApiUrl += '/api/worker';
                      }

                      mySky.portalAccounts['_local'] = {
                        'store': {
                          'sia': {
                            'workerApiUrl': workerApiUrl,
                            'apiPassword': apiPasswordCtrl.text,
                            'downloadUrl': downloadUrlCtrl.text,
                          }
                        }
                      };

                      setupServiceOrder('_local');

                      await mySky.savePortalAccounts();

                      final stores = createStoresFromConfig(
                        mySky.portalAccounts['_local'],
                        httpClient: mySky.httpClient,
                        node: s5Node,
                      );
                      s5Node.store = stores.values.first;
                      // TODO Configurable
                      s5Node.exposeStore = true;
                      await s5Node.store!.init();

                      context.pop();
                      setState(() {});

                      updateQuota();
                    }
                  } catch (e, st) {
                    showErrorDialog(context, e, st);
                  }
                },
                child: Text(
                  'Add Sia Renter',
                ),
              ),
              SizedBox(
                width: 8,
              ),
              if (devModeEnabled)
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final accessKey = TextEditingController();
                      final bucket = TextEditingController();
                      final endpoint = TextEditingController();
                      final secretKey = TextEditingController();

                      final dialogRes = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Add S3 Provider (advanced)'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: endpoint,
                                decoration: const InputDecoration(
                                  labelText: 'endpoint',
                                ),
                                autofocus: true,
                              ),
                              SizedBox(
                                height: 8,
                              ),
                              TextField(
                                controller: bucket,
                                decoration: const InputDecoration(
                                  labelText: 'bucket',
                                ),
                              ),
                              SizedBox(
                                height: 8,
                              ),
                              TextField(
                                controller: accessKey,
                                decoration: const InputDecoration(
                                  labelText: 'accessKey',
                                ),
                              ),
                              SizedBox(
                                height: 8,
                              ),
                              TextField(
                                controller: secretKey,
                                decoration: const InputDecoration(
                                  labelText: 'secretKey',
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => context.pop(),
                              child: Text(
                                'Cancel',
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => context.pop(true),
                              child: Text(
                                'Add',
                              ),
                            ),
                          ],
                        ),
                      );
                      if (dialogRes == true) {
                        showLoadingDialog(context, 'Setting up S3 remote...');

                        mySky.portalAccounts['_local'] = {
                          'store': {
                            's3': {
                              'accessKey': accessKey.text,
                              'bucket': bucket.text,
                              'endpoint': endpoint.text,
                              'secretKey': secretKey.text,
                            }
                          }
                        };

                        setupServiceOrder('_local');

                        await mySky.savePortalAccounts();

                        final stores = createStoresFromConfig(
                          mySky.portalAccounts['_local'],
                          httpClient: mySky.httpClient,
                          node: s5Node,
                        );
                        s5Node.store = stores.values.first;
                        s5Node.exposeStore = true;
                        await s5Node.store!.init();

                        context.pop();
                        setState(() {});

                        updateQuota();
                      }
                    } catch (e, st) {
                      showErrorDialog(context, e, st);
                    }
                  },
                  child: Text(
                    'Add S3 Provider',
                  ),
                ),
            ],
          ],
        ),
        SizedBox(
          height: 12,
        ),
        Text(
          'Uploads',
          style: titleTextStyle,
        ),
        SizedBox(
          height: 6,
        ),
        Text(
          'Files are only uploaded to the first (1.) service, the other ones are tried if the first one fails. Metadata and thumbnails are uploaded to all services you select below.',
        ),
        SizedBox(
          height: 6,
        ),
        Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                'Files',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final service in mySky.portalAccounts['enabledPortals'])
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: ChoiceChip(
                  showCheckmark: false,
                  avatar: mySky.fileUploadServiceOrder.contains(service)
                      ? Text(
                          '${mySky.fileUploadServiceOrder.indexOf(service) + 1}.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                  onSelected: (val) {
                    if (val) {
                      mySky.fileUploadServiceOrder.add(service);
                    } else {
                      mySky.fileUploadServiceOrder.remove(service);
                    }
                    setState(() {});
                    hasChanges.value = true;
                  },
                  label: Text(getServiceName(service)),
                  selected: mySky.fileUploadServiceOrder.contains(service),
                ),
              ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                'Metadata',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final service in mySky.portalAccounts['enabledPortals'])
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: ChoiceChip(
                  showCheckmark: false,
                  onSelected: (val) {
                    if (val) {
                      mySky.metadataUploadServiceOrder.add(service);
                    } else {
                      mySky.metadataUploadServiceOrder.remove(service);
                    }
                    setState(() {});
                    hasChanges.value = true;
                  },
                  label: Text(getServiceName(service)),
                  selected: mySky.metadataUploadServiceOrder.contains(service),
                ),
              ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                'Thumbnails',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final service in mySky.portalAccounts['enabledPortals'])
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: ChoiceChip(
                  showCheckmark: false,
                  onSelected: (val) {
                    if (val) {
                      mySky.thumbnailUploadServiceOrder.add(service);
                    } else {
                      mySky.thumbnailUploadServiceOrder.remove(service);
                    }
                    setState(() {});
                    hasChanges.value = true;
                  },
                  label: Text(getServiceName(service)),
                  selected: mySky.thumbnailUploadServiceOrder.contains(service),
                ),
              ),
          ],
        ),
        StreamBuilder(
          stream: hasChanges.values,
          builder: (context, snapshot) {
            if (snapshot.data == true)
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'You have unsaved changes. Remember to save!',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            return SizedBox();
          },
        ),
        SizedBox(
          height: 12,
        ),
        /*  Text(
          'Pinning Automation',
          style: titleTextStyle,
        ),
        SizedBox(
          height: 12,
        ), */
        Text(
          'Advanced',
          style: titleTextStyle,
        ),
        SizedBox(
          height: 6,
        ),
        Row(
          children: [
            ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Storage Services JSON'),
                    content: SizedBox(
                      width: dialogWidth,
                      height: dialogHeight,
                      child: SingleChildScrollView(
                        reverse: true,
                        child: SelectableText(
                          const JsonEncoder.withIndent('  ').convert(
                            mySky.portalAccounts,
                          ),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: Text(
                'View Full JSON',
              ),
            ),
          ],
        ),
        SizedBox(
          height: 12,
        ),
        TextField(
          decoration: InputDecoration(
            labelText: 'Enabled Services',
          ),
          controller: TextEditingController(
              text: json.encode(mySky.portalAccounts['enabledPortals'])),
          onChanged: (str) {
            try {
              final data = json.decode(str);
              for (final portal in data) {
                if (portal == '_local') continue;
                if (mySky.portalAccounts['portals'][portal] == null) {
                  throw 'Invalid portal $portal';
                }
              }
              mySky.portalAccounts['enabledPortals'] = data;
            } catch (_) {}
          },
        ),
        SizedBox(
          height: 16,
        ),
        TextField(
          decoration: InputDecoration(
            labelText: 'Old Upload Order',
          ),
          controller: TextEditingController(
              text: json.encode(mySky.portalAccounts['uploadPortalOrder'])),
          onChanged: (str) {
            try {
              final data = json.decode(str);
              for (final portal in data) {
                if (portal == '_local') continue;
                if (mySky.portalAccounts['portals'][portal] == null) {
                  throw 'Invalid portal $portal';
                }
              }
              mySky.portalAccounts['uploadPortalOrder'] = data;
            } catch (_) {}
          },
        ),
        /*    ElevatedButton(
          onPressed: () async {
            await pinAll(context, 'skyfs://root/home');
          },
          child: Text(
            'Ensure everything is pinned (can take a long time)',
          ),
        ), */
        /*  SizedBox(
          height: 16,
        ),
        TextField(
          decoration: InputDecoration(
            labelText: 'auth cookie',
          ),
          controller: ctrl,
          maxLines: 8,
          onChanged: (str) {
            if (!str.contains('skynet-jwt=')) {
              str = 'skynet-jwt=' + str;
            }
            dataBox.put('cookie', str.trim());
          },
        ), */
      ],
    );
  }

  void setupServiceOrder(String service) {
    mySky.fileUploadServiceOrder.remove(service);
    mySky.fileUploadServiceOrder.insert(0, service);

    mySky.metadataUploadServiceOrder.remove(service);
    mySky.metadataUploadServiceOrder.add(service);
    mySky.thumbnailUploadServiceOrder.remove(service);
    mySky.thumbnailUploadServiceOrder.add(service);

    mySky.portalAccounts['enabledPortals'].remove(service);
    mySky.portalAccounts['enabledPortals'].add(service);
  }

  String getServiceName(String name) {
    if (name == '_local') {
      return localStoreName ?? '_local';
    }
    return name;
  }

  Card _buildLocalStoreCard(BuildContext context) {
    final accountInfo = quotaService.accountInfos['_local'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Local (${localStoreName})',
                    style: titleTextStyle,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    quotaService.accountInfos.remove('_local');
                    setState(() {
                      mySky.portalAccounts['_local'] = null;
                    });
                    hasChanges.value = true;
                  },
                  child: Text(
                    'Remove',
                  ),
                ),
              ],
            ),
            QuotaWidget(context: context, portal: '_local'),
            if (accountInfo?.userIdentifier != null)
              Text('Account ID: ${accountInfo?.userIdentifier}'),
            if (accountInfo?.subscription != null)
              Text('Subscription: ${accountInfo!.subscription}'),
            if (accountInfo?.maxFileSize != null)
              Text('Max file size: ${filesize(accountInfo?.maxFileSize)}'),
          ],
        ),
      ),
    );
  }

  Card _buildPortalCard(String portal, BuildContext context) {
    final accountInfo = quotaService.accountInfos[portal];
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SelectableText(
                  portal,
                  style: titleTextStyle,
                ),
                Expanded(
                  child: SelectableText(
                    'id: ${accountInfo?.userIdentifier}',
                    textAlign: TextAlign.end,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Details'),
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SelectableText(
                              json.encode(
                                mySky.portalAccounts['portals'][portal],
                              ),
                            ),
                            Text(
                              'auth token available: ${dataBox.get(
                                    'portal_${portal}_auth_token',
                                  ) != null}',
                            ),
                            SizedBox(
                              height: 6,
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final portalInfo =
                                    mySky.portalAccounts['portals'][portal];
                                final link =
                                    '${portalInfo['protocol']}://$portal/accounts/set-auth-cookie/${dataBox.get(
                                  'portal_${portal}_auth_token',
                                )}';

                                FlutterClipboard.copy(link);
                              },
                              child: Text(
                                'Generate and copy auth link for web',
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => context.pop(),
                            child: Text('Close'),
                          )
                        ],
                      ),
                    );
                  },
                  icon: Icon(
                    UniconsLine.info_circle,
                  ),
                )
              ],
            ),
            if (accountInfo != null)
              QuotaWidget(context: context, portal: portal),
            if (false)
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 400,
                  child: SwitchListTile(
                    dense: true,
                    value: mySky.portalAccounts['portals'][portal]
                            ['autoPinEnabled'] ??
                        false,
                    title: Text(
                      'Auto-Pin enabled',
                    ),
                    subtitle: Text(
                      'When enabled, all data stored on one of your upload portals is replicated on this portal too',
                    ),
                    onChanged: (val) {
                      mySky.portalAccounts['portals'][portal]
                          ['autoPinEnabled'] = val;
                      setState(() {});
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
