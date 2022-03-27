import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';
import 'package:vup/utils/pin.dart';

import 'base.dart';

class PinAllVupAction extends VupFSAction {
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
    if (isFile) return null;
    if (entity == null) return null;

    return VupFSActionInstance(
      label: 'Pin all',
      icon: UniconsLine.refresh,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    await pinAll(
      context,
      instance.entity.uri!,
    );
  }
}
