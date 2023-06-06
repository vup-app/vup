import 'package:vup/app.dart';
import 'package:vup/queue/mdl.dart';
import 'package:vup/queue/sync.dart';
import 'package:vup/view/queue_task_manager.dart';

class ActiveQueueTasksView extends StatefulWidget {
  const ActiveQueueTasksView({Key? key}) : super(key: key);

  @override
  State<ActiveQueueTasksView> createState() => _ActiveQueueTasksViewState();
}

class _ActiveQueueTasksViewState extends State<ActiveQueueTasksView> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: StreamBuilder<void>(
        stream: Stream.periodic(Duration(milliseconds: 200)),
        builder: (context, snapshot) {
          if ((queue.runningTasks.length + queue.tasks.length) == 0) {
            return const SizedBox();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  'Active Tasks',
                  style: titleTextStyle,
                ),
              ),
              for (final task in queue.runningTasks.values)
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Text(
                          '${task is SyncQueueTask ? 'Sync' : task is MediaDownloadQueueTask ? 'Download' : task.toString()} ${task.id}',
                        ),
                      ),
                      if (task.progress > 0)
                        ClipRRect(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                          child: SizedBox(
                            height: 8,
                            child: LinearProgressIndicator(
                              value: task.progress,
                              backgroundColor: Theme.of(context).cardColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Text(
                  '${queue.tasks.length} tasks queued',
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: ElevatedButton(
                  child: const Text(
                    'Open Task Manager',
                  ),
                  onPressed: () {
                    context.push(
                      MaterialPageRoute(
                        builder: (context) => const QueueTaskManager(),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
