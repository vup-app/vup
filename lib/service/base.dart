import 'package:vup/generic/state.dart';

abstract class VupService {
  void verbose(dynamic str) {
    final line = ('[${this.runtimeType}] $str');
    print(line);
    logger.writeLine(line);
  }

  void info(dynamic str) {
    final line = ('[${this.runtimeType}] $str');
    print(line);
    logger.writeLine(line);
  }

  void warning(dynamic str) {
    final line = ('warn [${this.runtimeType}] $str');
    print(line);
    logger.writeLine(line);
  }

  void error(dynamic str) {
    final line = ('ERROR [${this.runtimeType}] $str');
    print(line);
    logger.writeLine(line);
  }
}
