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
        SizedBox(
          height: 12,
        ),
        ElevatedButton(
          onPressed: () async {
            showPortalDialog(context);
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
