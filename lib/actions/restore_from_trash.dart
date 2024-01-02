import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';
import 'package:vup/utils/strings.dart';

import 'base.dart';

class RestoreFromTrashVupAction extends VupFSAction {
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
    if (fileState.type != FileStateType.idle) return null;

    final uris = pathNotifier.selectedFiles.toList() +
        pathNotifier.selectedDirectories.toList();

    if (!isSelected) {
      uris.add(entity.uri);
    }

    for (final uri in uris) {
      if (!uri.startsWith('skyfs://root/.trash/')) {
        return null;
      }
    }

    if (!isSelected) {
      return VupFSActionInstance(
        label: 'Restore from Trash',
        icon: UniconsLine.export,
      );
    } else {
      return VupFSActionInstance(
        label:
            'Restore ${entity == null ? 'All' : renderFileSystemEntityCount(pathNotifier.selectedFiles.length, pathNotifier.selectedDirectories.length)} from Trash',
        icon: UniconsLine.export,
      );
    }
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    try {
      showLoadingDialog(context, 'Restoring from trash...');

      final files = <FileReference>[];
      if (instance.isSelected) {
        for (final uri in instance.pathNotifier.selectedFiles) {
          final path = storageService.dac.parseFilePath(uri);
          final di =
              storageService.dac.getDirectoryMetadataCached(path.directoryPath);
          files.add(di!.files[path.fileName]!);
        }
      } else {
        if (instance.isFile) {
          files.add(instance.entity);
        }
      }

      final directories = <DirectoryReference>[];
      if (instance.isSelected) {
        for (final uri in instance.pathNotifier.selectedDirectories) {
          final path = storageService.dac.parseFilePath(uri);
          final di =
              storageService.dac.getDirectoryMetadataCached(path.directoryPath);
          directories.add(di!.directories[path.fileName]!);
        }
      } else {
        if (!instance.isFile) {
          directories.add(instance.entity);
        }
      }

      final futures = <Future>[];
      for (final file in files) {
        futures.add(
          storageService.dac.moveFile(
            file.uri!,
            file.ext!['trash']['uri'] as String,
            trash: false,
          ),
        );
      }
      for (final dir in directories) {
        futures.add(
          storageService.dac.moveDirectory(
            dir.uri!,
            dir.ext!['trash']['uri'] as String,
            trash: false,
          ),
        );
      }
      await Future.wait(futures);

      if (instance.isSelected) {
        instance.pathNotifier.clearSelection();
      }

      context.pop();
    } catch (e, st) {
      context.pop();
      showErrorDialog(context, e, st);
    }
  }
}
