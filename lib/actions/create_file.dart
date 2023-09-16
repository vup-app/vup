import 'dart:io';

import 'package:filesystem_dac/dac.dart';
import 'package:path/path.dart';
import 'package:vup/app.dart';

import 'base.dart';

class CreateFileVupAction extends VupFSAction {
  @override
  VupFSActionInstance? check(
      bool isFile,
      dynamic entity,
      PathNotifierState pathNotifier,
      BuildContext context,
      bool isDirectoryView,
      bool hasWriteAccess,
      FileState fileState,
      bool isSelected) {
    if (!isDirectoryView) return null;
    if (!hasWriteAccess) return null;

    return VupFSActionInstance(
      label: 'Create new file',
      icon: UniconsLine.file_plus,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    final ctrl = TextEditingController(text: 'todo.txt');
    ctrl.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
    final name = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name your new file'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          onSubmitted: (value) => context.pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => context.pop(ctrl.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name != null) {
      try {
        final file =
            File(join(storageService.temporaryDirectory, 'new-files', name));
        file.createSync(recursive: true);

        await storageService.startFileUploadingTask(
          instance.pathNotifier.toCleanUri().toString(),
          file,
        );
      } catch (e, st) {
        showErrorDialog(context, e, st);
      }
    }
  }
}
