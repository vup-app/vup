import 'package:clipboard/clipboard.dart';
import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';

import 'base.dart';

class CopyURIVupAction extends VupFSAction {
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
    if (entity == null) return null;

    if (devModeEnabled) {
      return VupFSActionInstance(
        label: 'Copy URI (Debug)',
        icon: UniconsLine.clipboard,
      );
    }
    return null;
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    FlutterClipboard.copy(instance.entity.uri);
  }
}
