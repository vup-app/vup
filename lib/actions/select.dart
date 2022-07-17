import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';

import 'base.dart';

class SelectVupAction extends VupFSAction {
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
    if (isDoubleClickToOpenEnabled) return null;
    if (entity == null) return null;

    return VupFSActionInstance(
      label: isSelected ? 'Unselect...' : 'Select...',
      icon: UniconsLine.layer_group,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    final uri = instance.entity.uri;
    if (instance.entity is DirectoryDirectory) {
      if (instance.isSelected) {
        instance.pathNotifier.selectedDirectories.remove(uri);
        instance.pathNotifier.$();
      } else {
        instance.pathNotifier.selectedDirectories.add(uri);
        instance.pathNotifier.$();
      }
    } else {
      if (instance.isSelected) {
        instance.pathNotifier.selectedFiles.remove(uri);
        instance.pathNotifier.$();
      } else {
        instance.pathNotifier.selectedFiles.add(uri);
        instance.pathNotifier.$();
      }
    }
  }
}
