import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';
import 'package:vup/utils/strings.dart';

import 'base.dart';

class PermanentDeleteVupAction extends VupFSAction {
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
    final uris = pathNotifier.selectedFiles.toList() +
        pathNotifier.selectedDirectories.toList();
    if (!isSelected) {
      uris.add(entity.uri);
    }

    for (final uri in uris) {
      if (!uri.startsWith('skyfs://root/home/.trash/')) {
        return null;
      }
    }

    if (fileState.type != FileStateType.idle) return null;

    if (!isSelected) {
      return VupFSActionInstance(
        label: 'Delete ${isFile ? 'file' : 'directory'} permanently',
        icon: UniconsLine.trash,
      );
    } else {
      return VupFSActionInstance(
        label:
            'Delete ${entity == null ? 'all' : renderFileSystemEntityCount(pathNotifier.selectedFiles.length, pathNotifier.selectedDirectories.length)} permanently',
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
      final descriptionOfSelection = instance.isSelected
          ? renderFileSystemEntityCount(
              instance.pathNotifier.selectedFiles.length,
              instance.pathNotifier.selectedDirectories.length)
          : instance.isFile
              ? 'this file'
              : 'this directory';

      final res = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
              'Do you really want to permanently delete $descriptionOfSelection?'),
          // TODO !important verify that skylinks are only used once before unpinning them
          content: const Text(
            'Warning: If you ever copied these files, this operation could delete the copies too. So make sure that this is not the case and always have additional external backups of important data while Vup is still in beta!\n'
            'Another thing to keep in mind is that people you shared these files with might still have access to them because they made a copy.\n'
            'Also your file is not deleted from the network instantly, but this doesn\'t really matter in practice because after you delete the metadata the keys are lost and nobody can decrypt the file anymore.',
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => context.pop(true),
              child: const Text('Permanently delete'),
            ),
          ],
        ),
      );
      if (res != true) return;

      showLoadingDialog(
        context,
        'Deleting $descriptionOfSelection permanently...',
      );

      final Set directoryUris;
      final Set fileUris;

      if (instance.isSelected) {
        directoryUris = Set.from(instance.pathNotifier.selectedDirectories);
        fileUris = Set.from(instance.pathNotifier.selectedFiles);
      } else {
        if (instance.isFile) {
          directoryUris = {};
          fileUris = {instance.entity.uri};
        } else {
          directoryUris = {instance.entity.uri};
          fileUris = {};
        }
      }

      final futures = <Future>[];

      for (final uri in fileUris) {
        futures.add(storageService.dac.deleteFile(uri));
      }

      for (final uri in directoryUris) {
        futures.add(storageService.dac.deleteDirectoryRecursive(
          uri,
          unpinEverything: true,
        ));
      }

      await Future.wait(futures);
      final directoryRemoveFutures = <Future>[];

      for (final uri in directoryUris) {
        final path = storageService.dac.parseFilePath(uri);
        directoryRemoveFutures.add(storageService.dac.deleteDirectory(
          path.directoryPath,
          path.fileName,
        ));
      }
      await Future.wait(directoryRemoveFutures);

      instance.pathNotifier.clearSelection();
      context.pop();
    } catch (e, st) {
      context.pop();
      showErrorDialog(context, e, st);
    }
  }
}
