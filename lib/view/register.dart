import 'dart:math';

import 'package:clipboard/clipboard.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:random_string/random_string.dart';
import 'package:skynet/skynet.dart';

import 'package:skynet/src/mysky_seed/generation.dart';
import 'package:string_validator/string_validator.dart';
import 'package:skynet/src/portal_accounts/index.dart';

import 'package:vup/app.dart';
import 'package:vup/widget/hint_card.dart';
import 'package:vup/widget/sky_button.dart';

class RegisterView extends StatefulWidget {
  final TabController tabCtrl;
  RegisterView(this.tabCtrl);

  @override
  _RegisterViewState createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final emailCtrl = TextEditingController();

  var _loading = false;
  String? _error;

  bool _checked = false;

  String? mnemonic;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (mnemonic == null) ...[
          SizedBox(
            height: 12,
          ),
          Text(
            'Welcome to Vup!',
            style: titleTextStyle,
          ),
          SizedBox(
            height: 12,
          ),
          Text(
              'Vup is secure decentralized cloud storage. You can start here by creating a MySky account.'), //  An email address is required to register your siasky.net portal account.
          SizedBox(
            height: 24,
          ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Text(
            'What\'s your email?',
            style: subTitleTextStyle,
          ),
        ),
        Theme(
          data: Theme.of(context).copyWith(
            primaryColor: _error == null
                ? Theme.of(context).accentColor
                : SkyColors.error,
            accentColor: _error == null
                ? Theme.of(context).accentColor
                : SkyColors.error,
          ),
          child: TextFormField(
            controller: emailCtrl,
            decoration: InputDecoration(
              // TODO Add additional username for social features
              border: OutlineInputBorder(),
              hintText: 'Your email address',
              prefixIcon: Icon(UniconsLine.envelope),
            ),

            // autofocus: true,
            enabled: mnemonic == null,
            keyboardType: TextInputType.text,
          ),
        ),
        if (mnemonic == null) ...[
          if (_error != null) ...[
            SizedBox(
              height: 8,
            ),
            Row(
              children: [
                SizedBox(
                  width: 14,
                ),
                Icon(
                  UniconsLine.exclamation_triangle,
                  color: SkyColors.error,
                  size: 20,
                ),
                SizedBox(
                  width: 8,
                ),
                Flexible(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: SkyColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
        SizedBox(
          height: 4,
        ),
        if (mnemonic == null) ...[
          Text(
              'Your email address is only used for automatically creating an account on skynetfree.net which includes 100 GB of free storage.'),
          SizedBox(
            height: 24,
          ),
          Row(
            children: [
              Text(
                'Generate your word seed passphrase',
                style: subTitleTextStyle,
              ),
              InkWell(
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Icon(
                    UniconsLine.info_circle,
                    size: 22,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                onTap: () {
                  showInfoDialog(
                    context,
                    'Your word seed passphrase',
                    'This passphrase is the key to your MySky identity. Keep it secure, anyone who knows it can access and modify all of your files.',
                  );
                },
              ),
            ],
          ),
          SkyButton(
            extraHeight: 4,
            filled: true,
            color: Theme.of(context).colorScheme.secondary,
            onPressed: () {
              if (!isEmail(emailCtrl.text)) {
                setState(() {
                  _error = 'Please enter a valid email address';
                });
                return;
              }
              setState(() {
                _error = null;
                mnemonic = generatePhrase();
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(UniconsLine.subject),
                SizedBox(
                  width: 6,
                ),
                Text(
                  'Generate word seed',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (mnemonic != null) ...[
          SizedBox(
            height: 24,
          ),
          Text(
            'Your word seed passphrase',
            style: subTitleTextStyle,
          ),
          SizedBox(
            height: 12,
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.secondary,
                width: 0.5,
              ),
              borderRadius: BorderRadius.circular(4),
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withOpacity(SkyColors.cardBackgroundColorOpacity),
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 12,
            ),
            child: SelectableText(
              mnemonic!,
              style: TextStyle(
                fontSize: 18,
              ),
            ),
          ),
          Row(
            children: [
              buildWordSeedActionButton(
                context,
                () {
                  setState(() {
                    mnemonic = generatePhrase();
                  });
                },
                'New seed',
                UniconsLine.redo,
              ),
              SizedBox(
                width: 4,
              ),
              buildWordSeedActionButton(
                context,
                () {
                  FlutterClipboard.copy(mnemonic!).then(
                    (value) => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Seed copied successfully'),
                        duration: Duration(seconds: 2),
                      ),
                    ),
                  );
                },
                'Copy seed',
                UniconsLine.copy,
              ),
            ],
          ),
          SizedBox(
            height: 12,
          ),
          HintCard(
            icon: UniconsLine.exclamation_octagon,
            color: SkyColors.warning,
            content: Text(
              'Please write down your seed or store it in a secure location. You need it to recover your account in case your device gets destroyed or lost.',
              style: TextStyle(
                color: SkyColors.warning,
              ),
            ),
          ),
          SizedBox(
            height: 8,
          ),
          InkWell(
            onTap: () {
              setState(() {
                _checked = !_checked;
                if (_checked) {
                  _error = null;
                }
              });
            },
            child: Row(
              children: [
                Checkbox(
                  value: _checked,
                  // color: Theme.of(context).accentColor,

                  onChanged: (val) {
                    setState(() {
                      _checked = val ?? false;
                      if (_checked) {
                        _error = null;
                      }
                    });
                  },
                ),
                Flexible(
                  child: Text(
                    'I made a backup of my seed in a secure location.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: (_error != null) && !_checked
                          ? SkyColors.error
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 8,
          ),
          if (_error != null) ...[
            Row(
              children: [
                SizedBox(
                  width: 14,
                ),
                Icon(
                  UniconsLine.exclamation_triangle,
                  color: SkyColors.error,
                  size: 20,
                ),
                SizedBox(
                  width: 8,
                ),
                Flexible(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: SkyColors.error,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 16,
            ),
          ],
          SkyButton(
            extraHeight: 4,
            filled: true,
            color: Theme.of(context).colorScheme.secondary,
            child: _loading
                ? SpinKitWave(
                    color: Colors.white,
                    size: 25.0,
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(UniconsLine.padlock),
                      SizedBox(
                        width: 6,
                      ),
                      Text(
                        'Create account',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
            // enabled: _checked,
            onPressed: _loading
                ? null
                : () async {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });

                    try {
                      if (!_checked) {
                        throw 'Please confirm that you made a backup';
                      }
                      /* if (usernameCtrl.text.isEmpty) {
                        throw 'Please enter a username';
                      } */

                      if ((mnemonic ?? '').isEmpty)
                        throw 'Error: Something went horribly wrong, please report it (Code 635)';

                      // TODO Create profile

                      // NOTE: Use a large amount of bytes just to prevent any collisions. It's
                      // fine if the tweak is a little long.
                      final portalAccountTweak = randomAlphaNumeric(
                        64,
                        provider: CoreRandomProvider.from(
                          Random.secure(),
                        ),
                      );

                      mySky.skynetClient.portalHost = 'skynetfree.net';

                      final portalAccounts = {
                        mySky.skynetClient.portalHost: {
                          'activeAccountNickname': 'vup',
                          'accountNicknames': {
                            'vup': portalAccountTweak,
                          },
                        }
                      };

                      mySky.user =
                          await SkynetUser.fromMySkySeedPhrase(mnemonic!);

                      storageService.mySkyProvider.skynetUser = mySky.user;

                      final email = emailCtrl.text;

                      final jwt = await register(
                        mySky.skynetClient,
                        mySky.user.rawSeed,
                        email,
                        portalAccountTweak,
                      );
                      mySky.skynetClient.headers = {
                        'cookie': jwt,
                        'user-agent': vupUserAgent,
                      };
                      // print(jwt);

                      await storageService.mySkyProvider.setJSONEncrypted(
                        mySky.portalAccountsPath,
                        portalAccounts,
                        0,
                      );
                      dataBox.put('cookie', jwt);
                      dataBox.put('portal_host', mySky.skynetClient.portalHost);

                      dataBox.put('mysky_portal_auth_accounts', portalAccounts);
                      dataBox.put(
                        'mysky_portal_auth_ts',
                        DateTime.now().millisecondsSinceEpoch,
                      );

                      await mySky.storeSeedPhrase(mnemonic!);

                      await mySky.autoLogin();

                      // dataBox.put('seed', seed);

                      context.beamToNamed(
                        '/browse',
                        replaceCurrent: true,
                      );

                      /*         Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => HomePage([]),
                        ),
                      ); */
                      /* await skyId.setMnemonic(
                        mnemonic,
                        setInitialProfile: true,
                        username: usernameCtrl.text,
                      );
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => HomePage(),
                        ),
                      ); */
                    } catch (e) {
                      dataBox.delete('seed');
                      _error = e.toString();
                    }

                    setState(() {
                      _loading = false;
                    });
                  },
          ),
        ],
      ],
    );
  }

  InkWell buildWordSeedActionButton(
    BuildContext context,
    GestureTapCallback? onTap,
    String title,
    IconData iconData,
  ) {
    return InkWell(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Icon(
              iconData,
              color: Theme.of(context).colorScheme.secondary,
              size: 16,
            ),
            SizedBox(
              width: 8,
            ),
            Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
      onTap: onTap,
    );
  }
}
