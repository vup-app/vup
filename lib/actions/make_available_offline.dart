import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';

import 'base.dart';

class MakeAvailableOfflineVupAction extends VupFSAction {
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
        label:
            'Make ${pathNotifier.selectedFiles.length} files available offline',
        icon: UniconsLine.cloud_check,
      );
    } else {
      if (isAvailableOffline) return null;
      return VupFSActionInstance(
        label: 'Make file available offline',
        icon: UniconsLine.cloud_check,
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

    await Future.wait([
      for (final file in files)
        downloadPool.withResource(
          () => storageService.downloadAndDecryptFile(
            fileData: file.file,
            name: file.name,
            outFile: null,
          ),
        ),
    ]);
  }
}
