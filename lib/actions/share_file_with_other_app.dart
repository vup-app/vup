import 'package:filesystem_dac/dac.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:vup/app.dart';

import 'base.dart';

class ShareFileWithOtherAppVupAction extends VupFSAction {
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
    if (UniversalPlatform.isLinux || UniversalPlatform.isWindows) return null;
    if (!isFile) return null;
    if (entity == null) return null;
    if (fileState.type != FileStateType.idle) return null;

    if (isSelected) {
      return VupFSActionInstance(
        label:
            'Share ${pathNotifier.selectedFiles.length} files with other app',
        icon: UniconsLine.share,
      );
    } else {
      return VupFSActionInstance(
        label: 'Share file with other app',
        icon: UniconsLine.share,
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

    final links = await Future.wait([
      for (final file in files)
        downloadPool.withResource(
          () => storageService.downloadAndDecryptFile(
            fileData: file.file,
            name: file.name,
            outFile: null,
          ),
        ),
    ]);

    Share.shareFiles(links);
  }
}
