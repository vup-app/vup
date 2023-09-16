import 'package:intl/intl.dart';

String? dateTimeLocale;

String formatDateTime(DateTime dt) {
  return '${DateFormat.yMEd(dateTimeLocale).format(dt)} ${DateFormat.Hm(dateTimeLocale).format(dt)}';
}
