import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';

import 'base.dart';

class CreateDirectoryVupAction extends VupFSAction {
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
      label: 'Create new directory',
      icon: UniconsLine.folder_plus,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name your new directory'),
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
      showLoadingDialog(context, 'Creating directory...');
      try {
        await storageService.dac.createDirectory(
          instance.pathNotifier.toCleanUri().toString(),
          name.trim(),
        );
        context.pop();
        instance.pathNotifier.path = instance.pathNotifier.path + [name];
        globalIsHoveringDirectoryUri = null;
        instance.pathNotifier.$();
        globalIsHoveringDirectoryUri = null;
      } catch (e, st) {
        context.pop();
        showErrorDialog(context, e, st);
      }
    }
  }
}
