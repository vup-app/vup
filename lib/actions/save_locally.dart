import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:filesystem_dac/dac.dart';
import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:vup/app.dart';

import 'base.dart';

class SaveLocallyVupAction extends VupFSAction {
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

    return VupFSActionInstance(
      label: 'Save File Locally',
      icon: UniconsLine.download_alt,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    final file = instance.entity as FileReference;

    String? path;
    if (Platform.isAndroid || Platform.isIOS) {
      path = await FilePicker.platform.saveFile(
        fileName: file.name,
      );
    } else {
      path = (await file_selector.getSaveLocation(
        suggestedName: file.name,
      ))!
          .path;
    }

    if (path != null) {
      final localFile = File(path);
      /* showLoadingDialog(
                        context, 'Downloading and saving file...'); */
      await downloadPool.withResource(
        () => storageService.downloadAndDecryptFile(
          fileData: file.file,
          name: file.name,
          outFile: localFile,
          created: file.created,
          modified: file.modified,
        ),
      );
      // context.pop();
      // showInfoDialog(context, 'File saved successfully', '');
    }

    // FilePicker.platform.saveFile()
  }
}
