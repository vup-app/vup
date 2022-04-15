import 'package:vup/app.dart';
import 'package:vup/service/notification/provider/base.dart';

class FlutterNotificationProvider extends NotificationProvider {
  Future<void> show(
    int id,
    String? title,
    String? body, {
    String? payload,
  }) {
    return flutterLocalNotificationsPlugin!.show(
      id,
      title,
      body,
      syncNotificationChannelSpecifics,
      payload: payload,
    );
  }
}
