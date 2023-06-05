/* import 'dart:ffi';
import 'dart:io';

import 'package:s5_server/rust/bridge_generated.dart';

RustImpl initializeExternalLibrary(String path) {
  return RustImpl(
    Platform.isMacOS || Platform.isIOS
        ? DynamicLibrary.executable()
        : DynamicLibrary.open(path),
  );
}
 */