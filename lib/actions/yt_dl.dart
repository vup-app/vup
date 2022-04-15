import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';

import 'package:vup/view/yt_dl.dart';

import 'base.dart';

class YTDLVupAction extends VupFSAction {
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

    if (isYTDlIntegrationEnabled) {
      return VupFSActionInstance(
        label: 'YT-DL',
        icon: UniconsLine.image_download,
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
      builder: (context) => YTDLDialog(instance.pathNotifier.value.join('/')),
      barrierDismissible: false,
    );
  }
}
