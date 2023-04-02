import 'dart:typed_data';

import 'package:convert/convert.dart';

import '../generic/state.dart';

String calculateIdHash(List<int> bytes) {
  // TODO Check if this is lowercase
  return hex
      .encode(mySky.api.crypto.hashBlake3Sync(Uint8List.fromList(bytes)))
      .substring(0, 32);
}
