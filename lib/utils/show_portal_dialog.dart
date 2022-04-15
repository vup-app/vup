import 'dart:convert';

import 'package:selectable_autolink_text/selectable_autolink_text.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vup/app.dart';
import 'package:skynet/src/portal_accounts/index.dart';

Future<void> showPortalDialog(BuildContext context) async {
  final portalList = [
    {"host": "siasky.net", "public": true, "open": true},
    {"host": "fileportal.org", "public": true, "open": true},
    {"host": "skynetfree.net", "open": true},
    {"host": "skynetpro.net", "open": true},
    {"host": "seveysky.net", "open": true},
  ];

  showLoadingDialog(context, 'Loading saved portal accounts...');

  Map portalAccounts = {};

  try {
    final portalAccountsRes =
        await storageService.mySkyProvider.getJSONEncrypted(
      mySky.portalAccountsPath,
    );
    if (portalAccountsRes.data != null) {
      portalAccounts = portalAccountsRes.data;
    }
  } catch (_) {}
  context.pop();

  void _loginToPortal({
    required String portalAccountHost,
    required String portalHost,
    required String email,
    required String password,
  }) async {
    showLoadingDialog(
      context,
      'Connecting to portal...',
    );
    late String cookie;
    try {
      final res = await mySky.skynetClient.httpClient.post(
        Uri.https(portalAccountHost, '/api/login'),
        headers: {'content-type': 'application/json'},
        body: json.encode(
          {
            'email': email,
            'password': password,
          },
        ),
      );
      if (res.statusCode != 204) {
        throw 'Login failed (HTTP ${res.statusCode}: ${res.body})';
      }
      cookie = res.headers['set-cookie']!;
      context.pop();
    } catch (e, st) {
      context.pop();
      showErrorDialog(context, e, st);
      return;
    }

    mySky.skynetClient.portalHost = portalHost;
    mySky.skynetClient.headers = {
      'cookie': cookie,
      'user-agent': vupUserAgent,
    };

    dataBox.put(
      'cookie',
      cookie,
    );
    dataBox.put(
      'portal_host',
      portalHost,
    );
    dataBox.put(
      'mysky_portal_auth_ts',
      0,
    );

    context.pop();
    quotaService.clear();
    quotaService.update();
    showInfoDialog(context, 'Authentication successful',
        'You are now logged in to ${portalHost}');
  }

  String selectedPortal = 'other';
  try {
    selectedPortal = portalList.firstWhere(
        (element) => element['host'] == currentPortalHost)['host'] as String;
  } catch (_) {}
  final customPortalCtrl = TextEditingController();
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Choose a portal'),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: StatefulBuilder(builder: (context, sState) {
          return ListView(
            children: [
              for (final portal in portalList)
                RadioListTile<String>(
                  value: portal['host'] as String,
                  groupValue: selectedPortal,

                  /*    selected: selectedPortal ==
                                                  portal['host'], */
                  onChanged: (val) {
                    sState(() {
                      selectedPortal = portal['host'] as String;
                    });
                  },
                  title: Text(portal['host'].toString() +
                      (portalAccounts.containsKey(portal['host'])
                          ? ' [AUTO-LOGIN ENABLED]'
                          : '')),
                  subtitle: Text(
                    portal['public'] == true
                        ? 'Public portal'
                        : portal['open'] == true
                            ? 'Requires account'
                            : 'Closed',
                  ),
                ),
              RadioListTile(
                value: 'other',
                groupValue: selectedPortal,
                title: Text('Other'),
                onChanged: (_) {
                  sState(() {
                    selectedPortal = 'other';
                  });
                },
              ),
              if (selectedPortal == 'other')
                Padding(
                  padding: const EdgeInsets.only(left: 64.0),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Hostname',
                    ),
                    controller: customPortalCtrl,
                    autofocus: true,
                  ),
                ),
            ],
          );
        }),
      ),
      actions: [
        TextButton(
          onPressed: () {
            context.pop();
          },
          child: Text(
            'Cancel',
          ),
        ),
        TextButton(
          onPressed: () async {
            final portalHost = selectedPortal == 'other'
                ? customPortalCtrl.text
                : selectedPortal;
            final portalAccountHost = 'account.$portalHost';
            showLoadingDialog(
              context,
              'Connecting to portal...',
            );

            try {
              if (portalAccounts.containsKey(portalHost)) {
                final currentPortalAccounts = portalAccounts[portalHost];

                final portalAccountTweak =
                    currentPortalAccounts['accountNicknames']
                        [currentPortalAccounts['activeAccountNickname']];
                mySky.skynetClient.portalHost = portalHost;

                final jwt = await login(
                  mySky.skynetClient,
                  mySky.user.rawSeed,
                  portalAccountTweak,
                );

                mySky.skynetClient.headers = {
                  'cookie': jwt,
                  'user-agent': vupUserAgent,
                };

                dataBox.put('portal_host', portalHost);
                dataBox.put('cookie', jwt);

                dataBox.put('mysky_portal_auth_accounts', portalAccounts);
                dataBox.put(
                  'mysky_portal_auth_ts',
                  DateTime.now().millisecondsSinceEpoch,
                );

                context.pop();
                context.pop();
                quotaService.clear();
                quotaService.update();
                return;
              }

              final res = await mySky.skynetClient.httpClient
                  .get(Uri.https(portalAccountHost, '/health'));
              if (res.statusCode != 200)
                throw 'Could not connect (HTTP ${res.statusCode})';
              context.pop();
            } catch (e, st) {
              context.pop();
              showErrorDialog(context, e, st);
              return;
            }
            context.pop();
            final emailCtrl = TextEditingController();
            final passwordCtrl = TextEditingController();

            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  'Sign in to ${portalHost}',
                ),
                content: SizedBox(
                  height: dialogHeight,
                  width: dialogWidth,
                  child: Column(
                    children: [
                      SelectableAutoLinkText(
                        'You can create an account here if you don\'t have one yet: https://${portalAccountHost}/auth/registration',
                        onTap: (url) {
                          launch(url);
                        },
                        linkStyle: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      SizedBox(
                        height: 16,
                      ),
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'E-Mail Address',
                        ),
                        controller: emailCtrl,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      SizedBox(
                        height: 16,
                      ),
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Password',
                        ),
                        controller: passwordCtrl,
                        obscureText: true,
                        onSubmitted: (_) {
                          _loginToPortal(
                            email: emailCtrl.text,
                            password: passwordCtrl.text,
                            portalAccountHost: portalAccountHost,
                            portalHost: portalHost,
                          );
                        },
                      ),
                      SizedBox(
                        height: 16,
                      ),
                      ElevatedButton(
                        onPressed: () {
                          _loginToPortal(
                            email: emailCtrl.text,
                            password: passwordCtrl.text,
                            portalAccountHost: portalAccountHost,
                            portalHost: portalHost,
                          );
                        },
                        child: Text(
                          'Sign in',
                        ),
                      ),
                      SizedBox(
                        height: 16,
                      ),
                      TextButton(
                        onPressed: () {
                          mySky.skynetClient.portalHost = portalHost;
                          mySky.skynetClient.headers = {
                            'cookie': '',
                            'user-agent': vupUserAgent,
                          };

                          dataBox.put(
                            'cookie',
                            '',
                          );
                          dataBox.put(
                            'portal_host',
                            portalHost,
                          );
                          dataBox.put(
                            'mysky_portal_auth_ts',
                            0,
                          );

                          context.pop();
                          quotaService.clear();
                          quotaService.update();
                          showInfoDialog(context, 'Selected portal',
                              'You are now using ${portalHost}');
                        },
                        child: Text(
                          'Don\'t use an account (Not recommended)',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      context.pop();
                    },
                    child: Text(
                      'Cancel',
                    ),
                  ),
                ],
              ),
            );
          },
          child: Text(
            'Connect',
          ),
        ),
      ],
    ),
  );
}
