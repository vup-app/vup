import 'package:filesystem_dac/dac.dart';
import 'package:pool/pool.dart';
import 'package:random_string/random_string.dart';
import 'package:vup/app.dart';
import 'package:vup/queue/pin.dart';
import 'package:vup/utils/calculate_encrypted_size.dart';
import 'package:vup/utils/pin.dart';
import 'package:vup/utils/strings.dart';

import 'base.dart';

class PinVupAction extends VupFSAction {
  @override
  VupFSActionInstance? check(
    bool isFile,
    dynamic entity,
    PathNotifierState pathNotifier,
    BuildContext context,
    bool isDirectoryView,
    bool hasWriteAccess,
    FileState fileState,
    bool isSelected,
  ) {
    if (isDirectoryView) return null;

    if (!isSelected) {
      return VupFSActionInstance(
        label: 'Pin ${isFile ? 'File' : 'Directory'}',
        icon: UniconsLine.map_pin,
      );
    } else {
      return VupFSActionInstance(
        label:
            'Pin ${entity == null ? 'all' : renderFileSystemEntityCount(pathNotifier.selectedFiles.length, pathNotifier.selectedDirectories.length)}',
        icon: UniconsLine.map_pin,
      );
    }
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    final files = <String>[];
    final dirs = <String>[];
    if (instance.isSelected) {
      files.addAll(instance.pathNotifier.selectedFiles);
      dirs.addAll(instance.pathNotifier.selectedDirectories);
    } else {
      if (instance.isFile) {
        files.add(instance.entity.uri);
      } else {
        dirs.add(instance.entity.uri);
      }
    }
    final cids = <CID>[];
    void addHashes(FileReference file) {
      cids.add(
        file.file.encryptedCID != null
            ? CID(cidTypeRaw, file.file.encryptedCID!.encryptedBlobHash,
                size: calculateEncryptedFileSize(file.file))
            : file.file.cid,
      );
    }

    for (final uri in files) {
      final path = storageService.dac.parseFilePath(uri);
      final di =
          storageService.dac.getDirectoryMetadataCached(path.directoryPath);
      addHashes(di!.files[path.fileName]!);
    }

    for (final uri in dirs) {
      final di = await storageService.dac.getDirectoryMetadata(
        '$uri?recursive=true',
      );
      for (final file in di.files.values) {
        addHashes(file);
      }
    }
    final remote = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select storage location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final remote in mySky.allUploadServices)
              ListTile(
                title: Text(remote == '_local'
                    ? s5Node.store.runtimeType.toString()
                    : remote),
                onTap: () {
                  context.pop(remote);
                },
              )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
    if (remote != null) {
      queue.add(PinningQueueTask(
        id: '${cids.length} files\non $remote',
        dependencies: [],
        cids: cids,
        remote: remote,
      ));
    }
  }
}
