import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';
import 'package:vup/main.dart';

import 'base.dart';

class OpenInNewTabVupAction extends VupFSAction {
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
    if (context.isMobile) return null;

    return VupFSActionInstance(
      label: 'Open in new tab',
      icon: UniconsLine.external_link_alt,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    final newPathNotifier = PathNotifierState([]);
    if (instance.entity.uri?.startsWith('skyfs://') ?? false) {
      final uri = Uri.parse(instance.entity.uri!);

      newPathNotifier.queryParamaters = Map.from(
        uri.queryParameters,
      );

      if (uri.host == 'local') {
        newPathNotifier.path = uri.pathSegments.sublist(1);
      } else {
        newPathNotifier.path = [instance.entity.uri!];
      }
    } else {
      newPathNotifier.value = [
        ...instance.pathNotifier.value,
        instance.entity.name
      ];
    }
    appLayoutState.createTab(
      initialState: AppLayoutViewState(newPathNotifier),
    );
  }
}
