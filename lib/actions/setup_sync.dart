import 'dart:io';

import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';
import 'package:vup/view/setup_sync_dialog.dart';

import 'base.dart';

class SetupSyncVupAction extends VupFSAction {
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

    final activeSyncTask = () {
      for (final st in syncTasks.values) {
        if (st.remotePath == pathNotifier.path.join('/')) {
          return st;
        }
      }
    }();

    final isSyncEnabled = (activeSyncTask == null) && !(Platform.isIOS);

    if (isSyncEnabled) {
      return VupFSActionInstance(
        label: 'Setup Sync',
        icon: UniconsLine.cloud_redo,
      );
    }
    return null;
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    if (Platform.isAndroid) {
      await requestAndroidBackgroundPermissions();
    }
    return showDialog(
      context: context,
      builder: (context) => SetupSyncDialog(
        path: instance.pathNotifier.path.join('/'),
      ),
    );
  }
}
