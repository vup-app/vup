import 'dart:io';

import 'package:vup/app.dart';

class WebServerSettingsPage extends StatefulWidget {
  const WebServerSettingsPage({Key? key}) : super(key: key);

  @override
  _WebServerSettingsPageState createState() => _WebServerSettingsPageState();
}

class _WebServerSettingsPageState extends State<WebServerSettingsPage> {
  final ctrl = TextEditingController(text: webServerPort.toString());
  final bindIpCtrl = TextEditingController(text: webServerBindIp);

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(
          height: 16,
        ),
        CheckboxListTile(
          value: isWebServerEnabled,
          title: Text('Web Server enabled'),
          subtitle: Text(
            'When enabled, a HTTP server is started with directory listing and file downloading support. Warning: Anyone on your local network can access the web server',
          ),
          onChanged: (val) async {
            dataBox.put('web_server_enabled', val!);
            if (val) {
              if (Platform.isAndroid) {
                await requestAndroidBackgroundPermissions();
              }
              webServerService.start(webServerPort, webServerBindIp);
            } else {
              webServerService.stop();
            }
            setState(() {});
          },
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: 'Port',
            ),
            enabled: !isWebServerEnabled,
            onChanged: (s) {
              final val = int.tryParse(s);
              if (val == null) return;
              if (val < 1000) return;

              dataBox.put('web_server_port', val);
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
            enabled: !isWebServerEnabled,
            onChanged: (s) {
              dataBox.put('web_server_bindip', s);
            },
          ),
        ),
        if (isWebServerEnabled)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SelectableText(
              'Web server running at ${webServerBindIp}:${webServerPort}/home/\nStop the web server if you want to change any settings.',
            ),
          ),
      ],
    );
  }
}
