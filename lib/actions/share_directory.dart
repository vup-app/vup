import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';
import 'package:vup/view/share_dialog.dart';

import 'base.dart';

class ShareDirectoryVupAction extends VupFSAction {
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

    if (pathNotifier.value.length < 2) {
      if (pathNotifier.toUriString().startsWith('skyfs://root/')) {
        return null;
      }
    }
    return VupFSActionInstance(
      label: 'Share Directory',
      icon: UniconsLine.share_alt,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) {
    return showDialog(
      context: context,
      builder: (context) => ShareDialog(
        directoryUris: [
          instance.pathNotifier.value.join('/'),
        ],
      ),
      barrierDismissible: false,
    );
  }
}
