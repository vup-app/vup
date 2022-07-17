import 'package:filesystem_dac/dac.dart';
import 'package:vup/actions/add_to_quick_access.dart';
import 'package:vup/actions/copy.dart';
import 'package:vup/actions/copy_temporary_streaming_link.dart';
import 'package:vup/actions/copy_uri.dart';
import 'package:vup/actions/copy_web_server_url.dart';

import 'package:vup/actions/create_directory.dart';
import 'package:vup/actions/cut.dart';
import 'package:vup/actions/delete_from_device.dart';
import 'package:vup/actions/file_details.dart';
import 'package:vup/actions/make_available_offline.dart';
import 'package:vup/actions/move_to_trash.dart';
import 'package:vup/actions/open_in_new_tab.dart';
import 'package:vup/actions/open_parent_directory.dart';
import 'package:vup/actions/pin_all.dart';
import 'package:vup/actions/previous_versions.dart';
import 'package:vup/actions/regenerate_metadata.dart';
import 'package:vup/actions/remove_shared_directory.dart';
import 'package:vup/actions/rename_directory.dart';
import 'package:vup/actions/rename_file.dart';
import 'package:vup/actions/save_locally.dart';
import 'package:vup/actions/search.dart';
import 'package:vup/actions/select.dart';
import 'package:vup/actions/setup_sync.dart';
import 'package:vup/actions/share.dart';
import 'package:vup/actions/share_directory.dart';
import 'package:vup/actions/share_file_with_other_app.dart';
import 'package:vup/actions/share_webapp.dart';
import 'package:vup/actions/stream_to_cast_device.dart';
import 'package:vup/actions/upload_directory.dart';
import 'package:vup/actions/upload_files.dart';
import 'package:vup/actions/upload_media_files.dart';
import 'package:vup/actions/view_json.dart';
import 'package:vup/actions/yt_dl.dart';
import 'package:vup/app.dart';

// TODO New actions
// CreateNewFileVupAction
// Open terminal here

final allActions = <VupFSAction>[
  // ! Directory view actions
  SearchVupAction(),
  CreateDirectoryVupAction(),
  UploadFilesVupAction(),
  // TODO UploadDirectoryVupAction(),
  UploadMediaFilesVupAction(),
  YTDLVupAction(),
  SetupSyncVupAction(),
  ShareDirectoryVupAction(),
  ShareWebAppVupAction(),
  // ! FileSystemEntity Actions
  SelectVupAction(),
  OpenInNewTabVupAction(),
  RenameDirectoryVupAction(),
  RenameFileVupAction(),
  CopyWebServerLinkVupAction(),
  StreamToCastDeviceVupAction(),
  ShareFileWithOtherAppVupAction(),
  SaveLocallyVupAction(),
  CopyVupAction(),
  CutVupAction(),
  ShareVupAction(),

  MakeAvailableOfflineVupAction(),

  DeleteFromDeviceVupAction(),

  MoveToTrashVupAction(),
  AddToQuickAccessVupAction(),
  RemoveSharedDirectoryVupAction(),
  PinAllVupAction(),
  PreviousFileVersionsVupAction(),

  OpenParentDirectoryVupAction(),

  ShowFileDetailsVupAction(),
  CopyTemporaryStreamingLinkVupAction(),
  RegenerateMetadataVupAction(),
  CopyURIVupAction(),
  ViewJSONVupAction(),
];

List<VupFSActionInstance> generateActions(
  bool isFile,
  dynamic entity,
  PathNotifierState pathNotifier,
  BuildContext context,
  bool isDirectoryView,
  bool hasWriteAccess,
  FileState fileState,
) {
  final list = <VupFSActionInstance>[];
  final bool isSelected = entity == null
      ? pathNotifier.isInSelectionMode
      : isFile
          ? pathNotifier.selectedFiles.contains(entity.uri)
          : pathNotifier.selectedDirectories.contains(entity.uri);

  if (pathNotifier.toUriString() ==
      'skyfs://local/fs-dac.hns/vup.hns/.internal/shared-with-me') {
    hasWriteAccess = false;
  }

  for (final action in allActions) {
    final i = action.check(
      isFile,
      entity,
      pathNotifier,
      context,
      isDirectoryView,
      hasWriteAccess,
      fileState,
      isSelected,
    );

    if (i != null) {
      i.action = action;
      i.pathNotifier = pathNotifier;
      i.entity = entity;
      i.isFile = isFile;
      i.isSelected = isSelected;
      i.hasWriteAccess = hasWriteAccess;
      list.add(i);
    }
  }
  return list;
}

abstract class VupFSAction {
  VupFSActionInstance? check(
      bool isFile,
      dynamic entity,
      PathNotifierState pathNotifier,
      BuildContext context,
      bool isDirectoryView,
      bool hasWriteAccess,
      FileState fileState,
      bool isSelected);

  Future<dynamic> execute(
    BuildContext context,
    VupFSActionInstance instance,
  );
}

class VupFSActionInstance {
  final String label;

  final IconData? icon;

  late VupFSAction action;
  late PathNotifierState pathNotifier;
  late dynamic entity;
  late bool isFile;
  late bool isSelected;
  late bool hasWriteAccess;

  VupFSActionInstance({required this.label, this.icon});

  // TODO Keyboard shortcuts
}
