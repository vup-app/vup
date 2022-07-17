import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';

import 'base.dart';

class UploadFilesVupAction extends VupFSAction {
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
    if (!isDirectoryView) return null;
    if (!hasWriteAccess) return null;

    return VupFSActionInstance(
      label: 'Upload files',
      icon: UniconsLine.file_upload,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    final files = <File>[];
    if (Platform.isAndroid || Platform.isIOS) {
      final pickRes = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );
      if (pickRes != null) {
        for (final platformFile in pickRes.files) {
          files.add(File(platformFile.path!));
        }
      }
    } else {
      final res = await file_selector.openFiles();

      for (final xfile in res) {
        files.add(File(xfile.path));
      }
    }

    await uploadMultipleFiles(
      context,
      instance.pathNotifier.value.join('/'),
      files,
    );
  }
}
