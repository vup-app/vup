import 'package:clipboard/clipboard.dart';
import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';

import 'base.dart';

class CopyWebServerLinkVupAction extends VupFSAction {
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
    if (!isWebServerEnabled) return null;
    if (isDirectoryView) return null;
    if (!isFile) return null;
    if (entity == null) return null;

    return VupFSActionInstance(
      label: 'Copy Web Server URL',
      icon: UniconsLine.clipboard,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    FlutterClipboard.copy(
      Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: webServerPort,
        pathSegments: Uri.parse(instance.entity.uri!).pathSegments,
      ).toString(),
    );
  }
}
