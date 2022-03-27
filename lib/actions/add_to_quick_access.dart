import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';

import 'base.dart';

class AddToQuickAccessVupAction extends VupFSAction {
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

    if (sidebarService.isPinned(
      [...pathNotifier.path, entity.name].join('/'),
    )) {
      return null;
    }

    return VupFSActionInstance(
      label: 'Add to Quick Access',
      icon: UniconsLine.favorite,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    showLoadingDialog(context, 'Adding to Quick Access...');

    await sidebarService.pinDirectory(
      [...instance.pathNotifier.path, instance.entity.name].join('/'),
    );
    context.pop();
  }
}
