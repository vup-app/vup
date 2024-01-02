import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';

import 'base.dart';

class RemoveSharedDirectoryVupAction extends VupFSAction {
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
    if (pathNotifier.toUriString() != 'skyfs://root/vup.hns/shared-with-me') {
      return null;
    }

    return VupFSActionInstance(
      label: 'Remove Shared Directory',
      icon: UniconsLine.times,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    try {
      showLoadingDialog(context, 'Removing shared directory...');
      final res = await storageService.dac.doOperationOnDirectory(
        Uri.parse('skyfs://root/vup.hns/shared-with-me'),
        (directoryIndex, writeKey) async {
          directoryIndex.directories.remove(instance.entity.key);
        },
      );
      if (!res.success) throw res.error!;
      context.pop();
    } catch (e, st) {
      context.pop();
      showErrorDialog(context, e, st);
    }
  }
}
