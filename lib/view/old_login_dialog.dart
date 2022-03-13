import 'package:vup/app.dart';
import 'package:skynet/src/portal_accounts/old.dart';

class OldLoginDialog extends StatefulWidget {
  const OldLoginDialog({Key? key}) : super(key: key);

  @override
  _OldLoginDialogState createState() => _OldLoginDialogState();
}

class _OldLoginDialogState extends State<OldLoginDialog> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Login to ${currentPortalHost}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usernameCtrl,
            decoration: InputDecoration(
              labelText: 'Username',
            ),
            autofocus: true,
          ),
          SizedBox(
            height: 12,
          ),
          TextField(
            controller: _passwordCtrl,
            decoration: InputDecoration(
              labelText: 'Password',
            ),
            obscureText: true,
          ),
        ],
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
            showLoadingDialog(context, 'Logging in...');
            try {
              final session = PortalSession(storageService.mySky.skynetClient);

              await session.createPortalSession(
                _usernameCtrl.text,
                _passwordCtrl.text,
              );
              final cookie = 'skynet-jwt=${session.sessionKey}';
              storageService.mySky.skynetClient.headers = {
                'cookie': cookie,
                'user-agent': vupUserAgent,
              };
              dataBox.put('cookie', cookie);
              context.pop();
              context.pop(true);
            } catch (e, st) {
              context.pop();
              showErrorDialog(context, e, st);
            }
          },
          child: Text(
            'Login',
          ),
        ),
      ],
    );
  }
}
