import 'dart:io';

import 'package:vup/app.dart';

class WebDavSettingsPage extends StatefulWidget {
  const WebDavSettingsPage({Key? key}) : super(key: key);

  @override
  _WebDavSettingsPageState createState() => _WebDavSettingsPageState();
}

class _WebDavSettingsPageState extends State<WebDavSettingsPage> {
  final portCtrl = TextEditingController(text: webDavServerPort.toString());
  final bindIpCtrl = TextEditingController(text: webDavServerBindIp);
  final usernameCtrl = TextEditingController(text: webDavServerUsername);
  final passwordCtrl = TextEditingController(text: webDavServerPassword);
  var isPasswordHidden = true;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(
          height: 16,
        ),
        CheckboxListTile(
          value: isWebDavServerEnabled,
          title: Text('WebDav Server enabled'),
          subtitle: Text(
            'When enabled, a local WebDav server is started which exposes all common file operations for your SkyFS',
          ),
          onChanged: (val) async {
            dataBox.put('webdav_server_enabled', val!);
            if (val) {
              if (Platform.isAndroid) {
                await requestAndroidBackgroundPermissions();
              }
              webDavServerService.start(
                webDavServerPort,
                webDavServerBindIp,
                webDavServerUsername,
                webDavServerPassword,
              );
            } else {
              webDavServerService.stop();
            }
            setState(() {});
          },
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: portCtrl,
            decoration: InputDecoration(
              labelText: 'Port',
            ),
            enabled: !isWebDavServerEnabled,
            onChanged: (s) {
              final val = int.tryParse(s);
              if (val == null) return;
              if (val < 1000) return;

              dataBox.put('webdav_server_port', val);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: bindIpCtrl,
            decoration: InputDecoration(
              labelText: 'Bind IP',
            ),
            enabled: !isWebDavServerEnabled,
            onChanged: (s) {
              dataBox.put('webdav_server_bindip', s);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: usernameCtrl,
            decoration: InputDecoration(
              labelText: 'Username',
            ),
            enabled: !isWebDavServerEnabled,
            onChanged: (s) {
              dataBox.put('webdav_server_username', s);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: passwordCtrl,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    isPasswordHidden = !isPasswordHidden;
                  });
                },
                icon: Icon(
                  isPasswordHidden ? UniconsLine.eye_slash : UniconsLine.eye,
                ),
              ),
            ),
            enabled: !isWebDavServerEnabled,
            obscureText: isPasswordHidden,
            onChanged: (s) {
              dataBox.put('webdav_server_password', s);
            },
          ),
        ),
        if (isWebDavServerEnabled)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SelectableText(
              'WebDav server running at http://${webDavServerBindIp}:${webDavServerPort}\nStop the WebDav server if you want to change any settings.',
            ),
          ),
      ],
    );
  }
}
