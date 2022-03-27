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

    if (pathNotifier.value.length > 1) {
      return VupFSActionInstance(
        label: 'Share directory',
        icon: UniconsLine.share_alt,
      );
    }
    return null;
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
