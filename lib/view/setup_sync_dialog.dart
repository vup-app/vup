import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:uuid/uuid.dart';
import 'package:vup/app.dart';
import 'package:file_picker/file_picker.dart';

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:vup/model/sync_task.dart';

class SetupSyncDialog extends StatefulWidget {
  final String path;
  final SyncTask? initialTask;
  const SetupSyncDialog({required this.path, this.initialTask, Key? key})
      : super(key: key);

  @override
  _SetupSyncDialogState createState() => _SetupSyncDialogState();
}

class _SetupSyncDialogState extends State<SetupSyncDialog> {
  late SyncTask task;

  @override
  void initState() {
    task = widget.initialTask ?? SyncTask(remotePath: widget.path);

    if (UniversalPlatform.isAndroid) {
      _manageExternalStorageGranted = false;
      task.mode = SyncMode.sendOnly;
      _checkManageExternalStorageGranted();
    } else {
      _manageExternalStorageGranted = true;
    }
    super.initState();
  }

  bool isAndroid10 = false;

  _checkManageExternalStorageGranted() async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;

    // TODO Check if 30 is correct
    isAndroid10 = androidInfo.version.sdkInt >= 30;

    if (isAndroid10) {
      Permission.manageExternalStorage.isGranted.then((value) {
        setState(() {
          _manageExternalStorageGranted = value;
          if (value) {
            task.mode = SyncMode.sendAndReceive;
          }
        });
      });
    } else {
      Permission.storage.isGranted.then((value) {
        setState(() {
          _manageExternalStorageGranted = value;
          if (value) {
            task.mode = SyncMode.sendAndReceive;
          }
        });
      });
    }
  }

  bool _manageExternalStorageGranted = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Setup sync'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_manageExternalStorageGranted)
            ListTile(
              title: Text('WARNING: No write access!'),
              subtitle: Text('Click here to grant...'),
              onTap: () async {
                if (isAndroid10) {
                  await Permission.manageExternalStorage.request();
                } else {
                  await Permission.storage.request();
                }
                _checkManageExternalStorageGranted();
              },
            ),
          ListTile(
            title: Text('Vup directory'),
            subtitle: Text(task.remotePath),
          ),
          ListTile(
            title: Text('Local directory'),
            subtitle: Text(task.localPath == null
                ? 'Click to select...'
                : task.localPath!),
            onTap: () async {
              late final String? filePath;
              // FilePicker.platform.sa
              if (Platform.isAndroid || Platform.isIOS) {
                filePath = await FilePicker.platform.getDirectoryPath();
              } else {
                filePath = await file_selector.getDirectoryPath();
                //
              }

              if (filePath != null) {
                task.localPath = Directory(filePath).absolute.path;

                setState(() {});
              }
            },
          ),
          SizedBox(
            height: 8,
          ),
          if (!task.watch)
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: 'Auto Sync Interval',
              ),
              items: [
                DropdownMenuItem(
                  child: Text('Never'),
                  value: 0,
                ),
                for (final option in <List>[
                  // if (!(Platform.isAndroid || Platform.isIOS)) ...[
                  [
                    '1 minute',
                    Duration(
                      minutes: 1,
                    )
                  ],
                  [
                    '5 minutes',
                    Duration(
                      minutes: 5,
                    )
                  ],
                  // ],
                  [
                    '15 minutes',
                    Duration(
                      minutes: 15,
                    )
                  ],
                  [
                    '30 minutes',
                    Duration(
                      minutes: 30,
                    )
                  ],
                  [
                    '1 hour',
                    Duration(
                      hours: 1,
                    )
                  ],
                  [
                    '3 hours',
                    Duration(
                      hours: 3,
                    )
                  ],
                  [
                    '6 hours',
                    Duration(
                      hours: 6,
                    )
                  ],
                  [
                    '12 hours',
                    Duration(
                      hours: 12,
                    )
                  ],
                  [
                    '24 hours',
                    Duration(
                      hours: 24,
                    )
                  ],
                ])
                  DropdownMenuItem(
                    child: Text(option[0]),
                    value: option[1].inSeconds,
                  ),
              ],
              value: task.interval,
              onChanged: (i) {
                setState(() {
                  task.interval = i!;
                });
              },
            ),
          /*   (Platform.isIOS || Platform.isAndroid)
              ? SizedBox(
                  height: 16,
                )
              : */
          /* CheckboxListTile(
            title: Text('Watch for changes'),
            subtitle: Text('Warning: Very experimental and inefficient'),
            value: task.watch,
            onChanged: (val) {
              setState(() {
                task.interval = 0;
                task.watch = val!;
              });
            },
          ), */
          SizedBox(
            height: 8,
          ),
          DropdownButtonFormField<SyncMode>(
            decoration: InputDecoration(
              labelText: 'Mode',
            ),
            items: [
              if (_manageExternalStorageGranted) ...[
                DropdownMenuItem(
                  child: Text('Upload and Download'),
                  value: SyncMode.sendAndReceive,
                ),
              ],
              DropdownMenuItem(
                child: Text('Upload only'),
                value: SyncMode.sendOnly,
              ),
              if (_manageExternalStorageGranted) ...[
                DropdownMenuItem(
                  child: Text('Download only'),
                  value: SyncMode.receiveOnly,
                ),
              ],
            ],
            value: task.mode,
            onChanged: (m) {
              setState(() {
                task.mode = m!;
              });
            },
          ),
          SizedBox(
            height: 16,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.initialTask != null)
                TextButton(
                  onPressed: () {
                    syncTasks.delete(task.key);
                    context.pop();
                  },
                  child: Text(
                    'Remove task',
                  ),
                ),
              SizedBox(
                width: 8,
              ),
              ElevatedButton(
                onPressed: () {
                  try {
                    // TODO Check for parent and child dirs that conflict
                    if (task.localPath == null) {
                      throw 'No local directory selected';
                    }

                    syncTasks.put(task.key ?? Uuid().v4(), task);
                    storageService.setupWatchers();
                    context.pop();
                  } catch (e, st) {
                    showErrorDialog(context, e, st);
                  }
                },
                child: Text(
                  widget.initialTask == null ? 'Create' : 'Update',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
