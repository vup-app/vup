import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';

import 'base.dart';

class RenameDirectoryVupAction extends VupFSAction {
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
    if (isFile) return null;
    if (!hasWriteAccess) return null;
    if (entity == null) return null;
    if (fileState.type != FileStateType.idle) return null;

    return VupFSActionInstance(
      label: 'Rename directory',
      icon: UniconsLine.pen,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    final ctrl = TextEditingController(text: instance.entity.name);
    final name = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename your directory'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          onSubmitted: (value) => context.pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => context.pop(ctrl.text),
            child: Text('Rename'),
          ),
        ],
      ),
    );

    if (name != null) {
      showLoadingDialog(context, 'Renaming directory...');
      try {
        final res = await storageService.dac.moveDirectory(
          instance.entity.uri,
          storageService.dac
              .getChildUri(
                storageService.dac
                    .parsePath(instance.pathNotifier.path.join('/')),
                name.trim(),
              )
              .toString(),
        );
        if (!res.success) throw res.error!;
        context.pop();
      } catch (e, st) {
        context.pop();
        showErrorDialog(context, e, st);
      }
    }
  }
}
