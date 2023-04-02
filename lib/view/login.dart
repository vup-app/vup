import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:vup/app.dart';
import 'package:vup/widget/hint_card.dart';
import 'package:vup/widget/sky_button.dart';

import 'package:lib5/src/seed/seed.dart';
import 'package:lib5/util.dart';

class LoginView extends StatefulWidget {
  final TabController tabCtrl;
  LoginView(this.tabCtrl);

  @override
  _LoginViewState createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final passphraseCtrl = TextEditingController();

  var _loading = false;
  String? _error;

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 12,
          ),
          Text(
            'Securely sign in using your S5 identity',
            style: titleTextStyle,
          ),
          SizedBox(
            height: 12,
          ),
          Text(
              'Vup will ask you once to login. It then securely stores your identity and allows you to use it.'),
          SizedBox(
            height: 24,
          ),
          Row(
            children: [
              Text('Enter your word seed passphrase'),
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
                    'This passphrase is the key to your S5 identity. Keep it secure, anyone who knows it can access and modify all of your files.',
                  );
                },
              ),
            ],
          ),
          Theme(
            data: Theme.of(context).copyWith(
              primaryColor: _error == null
                  ? Theme.of(context).colorScheme.secondary
                  : SkyColors.error,
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    secondary: _error == null
                        ? Theme.of(context).colorScheme.secondary
                        : SkyColors.error,
                  ),
            ),
            child:
                /* SizedBox(
              height: 52,
              child:  */
                TextFormField(
              controller: passphraseCtrl,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Seed',
              ),

              autocorrect: false,
              enabled: !_loading,
              //autofocus: true,
              keyboardType: TextInputType.visiblePassword,
              /* validator: (s) =>
                    [28, 29].contains(s.trim().split(' ').length) ? null : '', */
              /* ), */
            ),
          ),
          SizedBox(
            height: 8,
          ),
          if (_error != null) ...[
            Row(
              children: [
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
              height: 8,
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
                        'Sign in',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
            onPressed: _loading
                ? null
                : () async {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    // _formKey.currentState.validate();
                    //await Future.delayed(Duration(seconds: 5));
                    try {
                      final seed = validatePhrase(
                        passphraseCtrl.text,
                        crypto: mySky.crypto,
                      );

                      /* logger.verbose(await authStorage.read());
                      return; */

                      final identity = await S5UserIdentity.fromSeedPhrase(
                        passphraseCtrl.text,
                        api: mySky.api,
                      );

                      await mySky.storeAuthPayload(
                        base64UrlNoPaddingEncode(
                          identity.pack(),
                        ),
                      );

                      await mySky.autoLogin();

                      await Future.delayed(Duration(seconds: 2));

                      await mySky.loadPortalAccounts();

                      context.beamToNamed(
                        '/browse',
                        replaceCurrent: true,
                      );
                    } catch (e, st) {
                      logger.verbose(e);
                      logger.verbose(st);
                      _error = e.toString();
                    }

                    setState(() {
                      _loading = false;
                    });
                  },
          ),
          SizedBox(
            height: 4,
          ),
          GestureDetector(
            onTap: () {
              showInfoDialog(
                context,
                'Oh no!',
                'Unfortunately, there is nothing we can do. Create a new account and make sure to remember the seed.',
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'I lost my word seed',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 24,
          ),
          HintCard(
            onTap: () {
              widget.tabCtrl.animateTo(1);
            },
            icon: UniconsLine.user_circle,
            title: 'I don\'t have an account, yet.',
            content: Text.rich(
              TextSpan(
                text: 'No problem, you can simply ',
                children: [
                  TextSpan(
                    text: 'register here',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
