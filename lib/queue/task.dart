abstract class QueueTask {
  String get id;
  List<String> get dependencies;
  Future<void> execute();
  double get progress;

  String get threadPool;
}
