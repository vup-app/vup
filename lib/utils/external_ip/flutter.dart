import 'package:vup/utils/external_ip/base.dart';
import 'package:network_info_plus/network_info_plus.dart';

class FlutterExternalIpAddressProvider extends ExternalIpAddressProvider {
  Future<String> getIpAddress() async {
    final info = NetworkInfo();
    String? ipAddress;
    try {
      ipAddress = await info.getWifiIP();
    } catch (_) {}
    return ipAddress ?? '127.0.0.1';
  }
}
