import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';
import 'package:vup/utils/strings.dart';
import 'package:vup/view/share_dialog.dart';

import 'base.dart';

class ShareVupAction extends VupFSAction {
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

    if (!isSelected) {
      return VupFSActionInstance(
        label: 'Share ${isFile ? 'file' : 'directory'}',
        icon: UniconsLine.share_alt,
      );
    } else {
      return VupFSActionInstance(
        label:
            'Share ${entity == null ? 'all' : renderFileSystemEntityCount(pathNotifier.selectedFiles.length, pathNotifier.selectedDirectories.length)}',
        icon: UniconsLine.share_alt,
      );
    }
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    if (instance.isSelected) {
      showDialog(
        context: context,
        builder: (context) => ShareDialog(
          directoryUris: instance.pathNotifier.selectedDirectories.toList(),
          fileUris: instance.pathNotifier.selectedFiles.toList(),
        ),
        barrierDismissible: false,
      );
    } else {
      if (instance.isFile) {
        showDialog(
          context: context,
          builder: (context) => ShareDialog(
            fileUris: [
              instance.entity.uri,
            ],
          ),
          barrierDismissible: false,
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => ShareDialog(
            directoryUris: [
              instance.entity.uri,
            ],
          ),
          barrierDismissible: false,
        );
      }
    }
  }
}
