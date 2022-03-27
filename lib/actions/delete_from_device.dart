import 'dart:io';

import 'package:filesystem_dac/dac.dart';
import 'package:path/path.dart';
import 'package:vup/app.dart';

import 'base.dart';

class DeleteFromDeviceVupAction extends VupFSAction {
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
    if (entity == null) return null;
    if (fileState.type != FileStateType.idle) return null;
    bool isAvailableOffline = localFiles.containsKey(entity.file.hash);

    if (isSelected) {
      return VupFSActionInstance(
        label: 'Delete ${pathNotifier.selectedFiles.length} local copies',
        icon: UniconsLine.cloud_times,
      );
    } else {
      if (!isAvailableOffline) return null;
      return VupFSActionInstance(
        label: 'Delete local copy',
        icon: UniconsLine.cloud_times,
      );
    }
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    final files = <DirectoryFile>[];
    if (instance.isSelected) {
      for (final uri in instance.pathNotifier.selectedFiles) {
        final path = storageService.dac.parseFilePath(uri);
        final di =
            storageService.dac.getDirectoryIndexCached(path.directoryPath);
        files.add(di!.files[path.fileName]!);
      }
    } else {
      files.add(instance.entity);
    }
    for (final file in files) {
      final hash = file.file.hash;
      try {
        final decryptedFile = File(join(
          storageService.dataDirectory,
          'local_files',
          hash,
          file.name,
        ));
        await decryptedFile.delete();
      } catch (_) {}
      localFiles.delete(hash);
    }
  }
}
