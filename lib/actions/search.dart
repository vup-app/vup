import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';

import 'base.dart';

class SearchVupAction extends VupFSAction {
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

    return VupFSActionInstance(
      label: 'Search',
      icon: UniconsLine.search,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    if (instance.pathNotifier.isSearching) {
      instance.pathNotifier.disableSearchMode();
    } else {
      instance.pathNotifier.enableSearchMode();
    }
  }
}
