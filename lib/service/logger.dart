import 'dart:io';

import 'package:path/path.dart';
import 'package:vup/service/base.dart';

class Global extends VupService {
  late final File logFile;
  late IOSink sink;

  late String logFilePath;

  Future<void> init(String path) async {
    logFile = File(
      join(
        path,
        'logs',
        '${DateTime.now().toIso8601String().replaceAll(':', '_')}.log.txt',
      ),
    );
    logFile.createSync(recursive: true);

    logFilePath = logFile.absolute.path;

    print('[logger] log file: ${logFilePath}');

    sink = logFile.openWrite();
  }

  void writeLine(String line) {
    sink.writeln(DateTime.now().toString() + ' ' + line);
  }
}
