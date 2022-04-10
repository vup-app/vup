import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';

import 'base.dart';

class UploadMediaFilesVupAction extends VupFSAction {
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
    if (!Platform.isIOS) return null;
    if (!isDirectoryView) return null;
    if (!hasWriteAccess) return null;

    return VupFSActionInstance(
      label: 'Upload media files',
      icon: UniconsLine.image_upload,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    final files = <File>[];

    final pickRes = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.media,
    );
    if (pickRes != null) {
      for (final platformFile in pickRes.files) {
        files.add(File(platformFile.path!));
      }
    }

    await uploadMultipleFiles(
      context,
      instance.pathNotifier.value.join('/'),
      files,
    );
  }
}
