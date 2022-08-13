import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:xdg_directories/xdg_directories.dart';
import 'package:path/path.dart';

bool get isRunningAsFlatpak => configHome.path.contains('app.vup.Vup');

Future<Directory> getTempDir() async {
  Directory tmpDir = await getTemporaryDirectory();
  if (Platform.isLinux && isRunningAsFlatpak && runtimeDir != null) {
    tmpDir = Directory(join(runtimeDir!.path, 'app', 'app.vup.Vup'));
  }
  return tmpDir;
}
