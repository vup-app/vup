import 'package:device_info_plus/device_info_plus.dart';
import 'package:vup/utils/device_info/base.dart';

class FlutterDeviceInfoProvider extends DeviceInfoProvider {
  Future<Map<String, dynamic>> load() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final deviceInfo = await deviceInfoPlugin.deviceInfo;
    return deviceInfo.toMap();
  }
}
