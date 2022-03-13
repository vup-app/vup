import 'package:intl/intl.dart';

String formatDateTime(DateTime dt) {
  return DateFormat.yMEd().format(dt) + ', ' + DateFormat.Hm().format(dt);
}
