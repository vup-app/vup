import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';

import 'base.dart';

class RenameFileVupAction extends VupFSAction {
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
    if (isDirectoryView) return null;
    if (!isFile) return null;
    if (!hasWriteAccess) return null;
    if (entity == null) return null;
    if (fileState.type != FileStateType.idle) return null;

    return VupFSActionInstance(
      label: 'Rename File',
      icon: UniconsLine.pen,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    final ctrl = TextEditingController(text: instance.entity.name);

    final parts = instance.entity.name.split('.');

    ctrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: ctrl.text.length -
          (parts.length > 1 ? (parts.last.length + 1) : 0) as int,
    );
    final name = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename your file'),
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
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (name != null) {
      showLoadingDialog(context, 'Renaming file...');
      try {
        await storageService.dac.renameFile(
          instance.entity.uri,
          name,
        );
        context.pop();
      } catch (e, st) {
        context.pop();
        showErrorDialog(context, e, st);
      }
    }
  }
}
