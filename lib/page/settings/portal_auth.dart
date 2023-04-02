import 'dart:convert';

import 'package:clipboard/clipboard.dart';
import 'package:vup/app.dart';
import 'package:lib5/util.dart';
import 'package:lib5/storage_service.dart';

import 'package:vup/utils/pin.dart';
import 'package:vup/utils/show_portal_dialog.dart';

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
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton(
          onPressed: () async {
            try {
              showLoadingDialog(context, 'Loading...');

              await mySky.loadPortalAccounts();

              context.pop();
              setState(() {});
            } catch (e, st) {
              context.pop();
              showErrorDialog(context, e, st);
            }
          },
          child: Text(
            'Load portal accounts',
          ),
        ),
        SizedBox(
          height: 16,
        ),
        TextField(
          decoration: InputDecoration(
            labelText: 'enabledPortals',
          ),
          controller: TextEditingController(
              text: json.encode(mySky.portalAccounts['enabledPortals'])),
          onChanged: (str) {
            try {
              final data = json.decode(str);
              mySky.portalAccounts['enabledPortals'] = data;
            } catch (_) {}
          },
        ),
        SizedBox(
          height: 16,
        ),
        TextField(
          decoration: InputDecoration(
            labelText: 'uploadPortalOrder',
          ),
          controller: TextEditingController(
              text: json.encode(mySky.portalAccounts['uploadPortalOrder'])),
          onChanged: (str) {
            try {
              final data = json.decode(str);
              mySky.portalAccounts['uploadPortalOrder'] = data;
            } catch (_) {}
          },
        ),

        SizedBox(
          height: 16,
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              showLoadingDialog(context, 'Saving...');

              await mySky.savePortalAccounts();

              context.pop();
              setState(() {});
            } catch (e, st) {
              context.pop();
              showErrorDialog(context, e, st);
            }
          },
          child: Text(
            'Save settings',
          ),
        ),

        StreamBuilder(
          stream: quotaService.stream,
          builder: (context, snapshot) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(quotaService.tooltip),
            );
          },
        ),

        for (final p in mySky.portalAccounts['portals'].keys)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    p,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SelectableText(
                      json.encode(mySky.portalAccounts['portals'][p])),
                  Text(
                    'auth token available: ${dataBox.get(
                          'portal_${p}_auth_token',
                        ) != null}',
                  ),
                  SizedBox(
                    height: 6,
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final portal = mySky.portalAccounts['portals'][p];
                      final link =
                          '${portal['protocol']}://$p/accounts/set-auth-cookie/${dataBox.get(
                        'portal_${p}_auth_token',
                      )}';

                      FlutterClipboard.copy(link);
                    },
                    child: Text(
                      'Generate and copy auth link for web',
                    ),
                  ),
                  SizedBox(
                    height: 6,
                  ),
                  SelectableText('account info: ' +
                      json.encode(quotaService.portalStats[p])),
                  SizedBox(
                    height: 6,
                  ),
                  SwitchListTile(
                    value: mySky.portalAccounts['portals'][p]
                            ['autoPinEnabled'] ??
                        false,
                    title: Text(
                      'Auto-Pin enabled',
                    ),
                    subtitle: Text(
                      'When enabled, all data stored on one of your upload portals is replicated on this portal too',
                    ),
                    onChanged: (val) {
                      mySky.portalAccounts['portals'][p]['autoPinEnabled'] =
                          val;
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
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
          height: 12,
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
        ElevatedButton(
          onPressed: () async {
            // final _emailCtrl = TextEditingController();
            final _portalCtrl = TextEditingController();
            final _authTokenCtrl = TextEditingController();

            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  'Register on new portal',
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'API URL',
                        hintText: 'https://example.com',
                      ),
                      controller: _portalCtrl,
                    ),
                    SizedBox(
                      height: 16,
                    ),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Auth Token (optional)',
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
                        showLoadingDialog(context, 'Registering on portal...');

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
                        mySky.portalAccounts['uploadPortalOrder']
                            .add(portalConfig.authority);

                        mySky.portalAccounts['enabledPortals']
                            .add(portalConfig.authority);

                        dataBox.put(
                          'portal_${portalConfig.authority}_auth_token',
                          authToken,
                        );

                        await mySky.savePortalAccounts();
                        context.pop();
                        context.pop();
                        setState(() {});
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
            'Register on new portal',
          ),
        ),
        SizedBox(
          height: 16,
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
}
