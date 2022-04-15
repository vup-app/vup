import 'dart:math';

import 'package:random_string/random_string.dart';
import 'package:vup/app.dart';
import 'package:skynet/src/portal_accounts/index.dart';
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
        StreamBuilder(
          stream: quotaService.stream,
          builder: (context, snapshot) {
            return Text(quotaService.tooltip);
          },
        ),
        if ((dataBox.get('mysky_portal_auth_ts') ?? 0) != 0) ...[
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

                final portalAccounts =
                    dataBox.get('mysky_portal_auth_accounts');
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
                mySky.skynetClient.headers = {'cookie': jwt};
                dataBox.put('cookie', jwt);

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
              'Auto-refresh auth cookie',
            ),
          ),
        ],
        if ((dataBox.get('mysky_portal_auth_ts') ?? 0) == 0 &&
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
        ],
        SizedBox(
          height: 12,
        ),
        ElevatedButton(
          onPressed: () async {
            await showPortalDialog(context);
            setState(() {});
          },
          child: Text(
            'Choose a portal and login',
          ),
        ),
        SizedBox(
          height: 16,
        ),
        ElevatedButton(
          onPressed: () async {
            await pinAll(context, 'skyfs://local/fs-dac.hns/home');
          },
          child: Text(
            'Ensure everything is pinned (can take a long time)',
          ),
        ),
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
