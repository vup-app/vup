abstract class VupAction {
  Future<void> run(Map<String, dynamic> config);

  void info(dynamic str) {
    print('[${this.runtimeType}] $str');
  }

  void error(dynamic str) {
    print('ERROR [${this.runtimeType}] $str');
  }
}
