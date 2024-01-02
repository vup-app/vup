import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';
import 'package:vup/view/file_details_dialog.dart';

import 'base.dart';

class OpenParentDirectoryVupAction extends VupFSAction {
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
    if (!pathNotifier.isSearching) return null;

    return VupFSActionInstance(
      label: 'Open Parent Directory',
      icon: UniconsLine.folder_open,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    var uri = Uri.parse(instance.entity.uri!);

    uri = uri.replace(
        pathSegments: uri.pathSegments.sublist(0, uri.pathSegments.length - 1));

    instance.pathNotifier.navigateToUri(uri.toString());
  }
}
