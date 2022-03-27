import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';
import 'package:vup/utils/strings.dart';

import 'base.dart';

class CutVupAction extends VupFSAction {
  @override
  VupFSActionInstance? check(
    bool isFile,
    dynamic entity,
    PathNotifierState pathNotifier,
    BuildContext context,
    bool isDirectoryView,
    bool hasWriteAccess,
    FileState fileState,
    bool isSelected,
  ) {
    if (isDirectoryView) return null;
    if (!hasWriteAccess) return null;
    if (fileState.type != FileStateType.idle) return null;

    if (!isSelected) {
      return VupFSActionInstance(
        label: 'Cut ${isFile ? 'file' : 'directory'}',
        icon: UniconsLine.file_export,
      );
    } else {
      return VupFSActionInstance(
        label:
            'Cut ${entity == null ? 'all' : renderFileSystemEntityCount(pathNotifier.selectedFiles.length, pathNotifier.selectedDirectories.length)}',
        icon: UniconsLine.file_export,
      );
    }
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    if (instance.isSelected) {
      globalClipboardState.directoryUris =
          Set.from(instance.pathNotifier.selectedDirectories);
      globalClipboardState.fileUris =
          Set.from(instance.pathNotifier.selectedFiles);
    } else {
      if (instance.isFile) {
        globalClipboardState.directoryUris = {};
        globalClipboardState.fileUris = {instance.entity.uri};
      } else {
        globalClipboardState.directoryUris = {instance.entity.uri};
        globalClipboardState.fileUris = {};
      }
    }
    globalClipboardState.isCopy = false;
    globalClipboardState.$();
    instance.pathNotifier.clearSelection();
  }
}
