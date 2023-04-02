import 'dart:async';

import 'package:flutter/src/foundation/key.dart';
import 'package:flutter/src/widgets/container.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:vup/app.dart';
import 'package:vup/queue/sync.dart';
import 'package:vup/queue/task.dart';

class QueueTaskManager extends StatefulWidget {
  const QueueTaskManager({Key? key}) : super(key: key);

  @override
  State<QueueTaskManager> createState() => _QueueTaskManagerState();
}

class _QueueTaskManagerState extends State<QueueTaskManager> {
  late final StreamSubscription sub;

  @override
  void initState() {
    sub = Stream.periodic(Duration(milliseconds: 250)).listen((event) {
      setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Queue Task Manager'),
      ),
      body: Padding(
        padding: const EdgeInsets.only(
          left: 8.0,
          right: 8,
          top: 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Running tasks (${queue.runningTasks.length})',
              style: titleTextStyle,
            ),
            for (final task in queue.runningTasks.values) TaskRow(task),
            SizedBox(
              height: 8,
            ),
            Row(
              children: [
                Text(
                  'Queued tasks (${queue.tasks.length})',
                  style: titleTextStyle,
                ),
                SizedBox(
                  width: 8,
                ),
                TextButton(
                  onPressed: () {
                    for (final id in queue.tasks.keys.toList()) {
                      queue.failTask(id);
                    }
                  },
                  child: Text(
                    'Cancel all',
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: queue.tasks.length,
                itemBuilder: (context, index) {
                  final id = queue.tasks.keys.toList()[index];
                  return TaskRow(queue.tasks[id]!);
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

class TaskRow extends StatelessWidget {
  final QueueTask task;
  const TaskRow(this.task, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (task.progress > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: SizedBox(
                width: 100,
                height: 6,
                child: LinearProgressIndicator(
                  value: task.progress,
                  backgroundColor: Theme.of(context).cardColor,
                ),
              ),
            ),
          Expanded(
            child: Text(
              '${task is SyncQueueTask ? 'sync' : task.toString()}: ${task.id}',
            ),
          ),
        ],
      ),
    );
  }
}
