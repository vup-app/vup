import 'package:pool/pool.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/queue/task.dart';

class QueueService {
  final tasks = <String, QueueTask>{};
  final runningTasks = <String, QueueTask>{};

  final threadPools = <String, int>{
    'sync': 8,
    'mdl': 8,
    'pin': 8,
  };

  // final finishedTaskIds = <String>{};

  final _triggerPool = Pool(1);

  QueueService() {
    Stream.periodic(Duration(seconds: 1)).listen((event) {
      _triggerPool.withResource(() => _triggerCheck());
    });
  }
  void add(QueueTask task) {
    logger.verbose('add ${task.id}');
    if (tasks.containsKey(task.id) || runningTasks.containsKey(task.id)) {
      throw 'Duplicate task id!!';
    }
    tasks[task.id] = task;
  }

  Future<void> _triggerCheck() async {
    for (final pool in threadPools.keys) {
      int usedThreads = 0;
      for (final task in runningTasks.values) {
        if (task.threadPool == pool) {
          usedThreads++;
        }
      }

      while (usedThreads < 8) {
        QueueTask? selectedTask;

        for (final task in tasks.values) {
          if (task.threadPool != pool) continue;
          if (task.dependencies.where((d) => tasks.containsKey(d)).isEmpty &&
              task.dependencies
                  .where((d) => runningTasks.containsKey(d))
                  .isEmpty) {
            selectedTask = task;
            break;
          }
        }
        if (selectedTask != null) {
          runningTasks[selectedTask.id] = tasks.remove(selectedTask.id)!;
          usedThreads++;
          _execute(selectedTask);
        } else {
          break;
        }
      }
    }
  }

  Future<void> _execute(QueueTask task) async {
    logger.verbose('execute $task');
    try {
      await task.execute();
    } catch (e, st) {
      logger.verbose(e);
      logger.verbose(st);
      failTask(task.id);
      globalErrorsState.addError(e, '$task');
    }
    runningTasks.remove(task.id);
  }

  void cancelTask(QueueTask task) {
    task.cancel();
    runningTasks.remove(task.id);
  }

  void failTask(String id) {
    for (final task in tasks.values.toList()) {
      if (task.dependencies.contains(id)) {
        failTask(task.id);
      }
    }
    tasks.remove(id);
  }
}
