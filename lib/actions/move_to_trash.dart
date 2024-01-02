import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';
import 'package:vup/utils/strings.dart';

import 'base.dart';

class MoveToTrashVupAction extends VupFSAction {
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
        label: 'Move to Trash',
        icon: UniconsLine.trash,
      );
    } else {
      return VupFSActionInstance(
        label:
            'Move ${entity == null ? 'All' : renderFileSystemEntityCount(pathNotifier.selectedFiles.length, pathNotifier.selectedDirectories.length)} to Trash',
        icon: UniconsLine.trash,
      );
    }
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    try {
      showLoadingDialog(context, 'Moving to trash...');
      if (instance.isSelected) {
        final futures = <Future>[];
        for (final uri in instance.pathNotifier.selectedFiles) {
          // TODO Optimize with moveMultipleFiles method
          futures.add(
            storageService.dac.moveFile(
              uri,
              storageService.trashPath + '/' + Uri.parse(uri).pathSegments.last,
              generateRandomKey: true,
              trash: true,
            ),
          );
        }
        for (final uri in instance.pathNotifier.selectedDirectories) {
          futures.add(
            storageService.dac.moveDirectory(
              uri,
              storageService.trashPath +
                  '/' +
                  Uri.parse(uri).pathSegments.last +
                  ' (${DateTime.now().toString().split('.').first})',
              trash: true,
            ),
          );
        }
        await Future.wait(futures);
        instance.pathNotifier.clearSelection();
      } else {
        final uri = instance.entity.uri;
        if (instance.isFile) {
          await storageService.dac.moveFile(
            uri,
            storageService.trashPath + '/' + Uri.parse(uri).pathSegments.last,
            generateRandomKey: true,
            trash: true,
          );
        } else {
          await storageService.dac.moveDirectory(
            uri,
            storageService.trashPath +
                '/' +
                Uri.parse(uri).pathSegments.last +
                ' (${DateTime.now().toString().split('.').first})',
            trash: true,
          );
        }
      }
      context.pop();
    } catch (e, st) {
      context.pop();
      showErrorDialog(context, e, st);
    }
  }
}
