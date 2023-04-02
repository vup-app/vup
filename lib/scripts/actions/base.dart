import 'package:vup/generic/state.dart';

abstract class VupAction {
  Future<void> run(Map<String, dynamic> config);

  void info(dynamic str) {
    print('[$runtimeType] $str');
    logger.writeLine('[$runtimeType] $str');
  }

  void error(dynamic str) {
    print('ERROR [$runtimeType] $str');
    logger.writeLine('ERROR [$runtimeType] $str');
  }
}
