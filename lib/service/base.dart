// ignore_for_file: avoid_print

import 'package:vup/generic/state.dart';

abstract class VupService {
  void verbose(dynamic str) {
    final line = ('[$runtimeType] $str');
    print(line);
    logger.writeLine(line);
  }

  void info(dynamic str) {
    final line = ('[$runtimeType] $str');
    print(line);
    logger.writeLine(line);
  }

  void warning(dynamic str) {
    final line = ('warn [$runtimeType] $str');
    print(line);
    logger.writeLine(line);
  }

  void error(dynamic str) {
    final line = ('ERROR [$runtimeType] $str');
    print(line);
    logger.writeLine(line);
  }

  void catched(dynamic e, dynamic st) {
    warning(e);
    verbose(st);
  }
}
