import 'package:clipboard/clipboard.dart';
import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';

import 'base.dart';

class CopyTemporaryStreamingLinkVupAction extends VupFSAction {
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

    return VupFSActionInstance(
      label: 'Copy temporary streaming link',
      icon: UniconsLine.clipboard,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    FlutterClipboard.copy(
      await temporaryStreamingServerService.makeFileAvailable(
        instance.entity,
      ),
    );
  }
}
