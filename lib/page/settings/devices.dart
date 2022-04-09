import 'package:timeago/timeago.dart' as timeago;
import 'package:vup/app.dart';

class DevicesSettingsPage extends StatefulWidget {
  const DevicesSettingsPage({Key? key}) : super(key: key);

  @override
  _DevicesSettingsPageState createState() => _DevicesSettingsPageState();
}

class _DevicesSettingsPageState extends State<DevicesSettingsPage> {
  Map? deviceList;

  @override
  void initState() {
    _load();
    super.initState();
  }

  void _load() async {
    deviceList = await mySky.fetchDeviceList();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (deviceList == null)
      return Align(
        alignment: Alignment.topCenter,
        child: LinearProgressIndicator(),
      );
    return ListView(
      // padding: const EdgeInsets.all(16),
      children: [
        for (final deviceId in deviceList!['devices'].keys)
          _buildDevice(deviceId),
      ],
    );
  }

  ListTile _buildDevice(String deviceId) {
    final device = deviceList!['devices'][deviceId]!;
    var title =
        '${device['info']['prettyName'] ?? device['info']['computerName'] ?? device['info']['device'] ?? device['info']['name']} (created ${timeago.format(DateTime.fromMillisecondsSinceEpoch(device['created']))}) [${deviceId}]';

    if (deviceId == dataBox.get('deviceId')) {
      title = '$title (this device)';
    }
    (device['info']).remove('systemFeatures');

    return ListTile(
      title: Text(title),
      subtitle: SelectableText(device.toString()),
    );
  }
}
