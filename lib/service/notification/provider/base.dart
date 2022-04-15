abstract class NotificationProvider {
  Future<void> show(
    int id,
    String? title,
    String? body, {
    String? payload,
  });
}
