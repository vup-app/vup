import 'package:vup/utils/external_ip/base.dart';

class DockerExternalIpAddressProvider extends ExternalIpAddressProvider {
  Future<String> getIpAddress() async {
    return '127.0.0.1';
  }
}
