import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';
import 'package:vup/view/file_details_dialog.dart';

import 'base.dart';

class ShowFileDetailsVupAction extends VupFSAction {
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

    return VupFSActionInstance(
      label: 'Details',
      icon: UniconsLine.document_info,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('File Details'),
        content: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: FileDetailsDialog(
            instance.entity,
            hasWriteAccess: instance.hasWriteAccess,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: const Text(
              'Close',
            ),
          ),
        ],
      ),
    );
  }
}
