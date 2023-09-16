abstract class QueueTask {
  String get id;
  List<String> get dependencies;
  Future<void> execute();
  void cancel() {}

  double get progress;

  String get threadPool;
}
