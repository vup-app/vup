import 'dart:io';

import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';

import 'base.dart';

class RegenerateMetadataVupAction extends VupFSAction {
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
    if (!devModeEnabled) return null;
    if (!hasWriteAccess) return null;
    if (!isFile) return null;
    if (entity == null) return null;
    if (fileState.type != FileStateType.idle) return null;

    if (isSelected) {
      return VupFSActionInstance(
        label:
            'Re-generate metadata for ${pathNotifier.selectedFiles.length} files',
        icon: UniconsLine.redo,
      );
    } else {
      return VupFSActionInstance(
        label: 'Re-generate metadata',
        icon: UniconsLine.redo,
      );
    }
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    final files = <FileReference>[];
    if (instance.isSelected) {
      for (final uri in instance.pathNotifier.selectedFiles) {
        final path = storageService.dac.parseFilePath(uri);
        final di =
            storageService.dac.getDirectoryMetadataCached(path.directoryPath);
        files.add(di!.files[path.fileName]!);
      }
    } else {
      files.add(instance.entity);
    }

    for (final file in files) {
      try {
        final link = await downloadPool.withResource(
          () => storageService.downloadAndDecryptFile(
            fileData: file.file,
            name: file.name,
            outFile: null,
          ),
        );
        final fileData = await storageService.startFileUploadingTask(
          'vup.hns',
          File(link),
          metadataOnly: true,
        );
        logger.verbose(fileData);
        await storageService.dac.updateFileExtensionDataAndThumbnail(
          file.uri!,
          fileData!.ext,
          fileData.thumbnail,
        );

        /*   storageService.dac
            .getFileStateChangeNotifier(fileData.cid.hash)
            .updateFileState(
              FileState(
                type: FileStateType.idle,
                progress: 0,
              ),
            ); */
      } catch (e, st) {
        showErrorDialog(context, e, st);
      }
    }
  }
}
