import 'dart:io';

import 'package:vup/generic/state.dart';
import 'package:vup/service/notification/provider/base.dart';

class AppriseNotificationProvider extends NotificationProvider {
  static var servers = <String>[];
  Future<void> show(
    int id,
    String? title,
    String? body, {
    String? payload,
  }) async {
    logger.info('[AppriseNotificationProvider] $title $body');
    if (servers.isNotEmpty) {
      await Process.run(
        '/root/.local/bin/apprise',
        [
          '-t',
          title ?? '',
          '-b',
          body ?? '',
          ...servers,
        ],
      );
    }
  }
}
