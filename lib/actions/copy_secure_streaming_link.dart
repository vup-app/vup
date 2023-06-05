import 'package:clipboard/clipboard.dart';
import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';

import 'base.dart';

class CopySecureStreamingLinkVupAction extends VupFSAction {
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
    if (!devModeEnabled) return null;

    return VupFSActionInstance(
      label: 'Copy secure streaming link',
      icon: UniconsLine.clipboard,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    final file = (instance.entity as FileReference);
    FlutterClipboard.copy(
      'https://s5.cx/#${file.file.encryptedCID!.toBase64Url()}?mediaType=${Uri.encodeComponent(
        file.mimeType ?? 'application/octet-stream',
      )}',
    );
  }
}
