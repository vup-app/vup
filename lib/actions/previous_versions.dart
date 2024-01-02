import 'package:filesize/filesize.dart';
import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';
import 'package:vup/utils/date_format.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'base.dart';

class PreviousFileVersionsVupAction extends VupFSAction {
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
    if (entity.version < 1) return null;
    if (fileState.type != FileStateType.idle) return null;

    return VupFSActionInstance(
      label: 'Previous Versions',
      icon: UniconsLine.history,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Previous versions'),
        content: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: ListView(
            children: [
              for (final version
                  in (instance.entity.history ?? {}).keys.toList().reversed)
                _buildPreviousVersion(
                  context,
                  version,
                  instance.hasWriteAccess,
                  instance.entity as FileReference,
                  instance.pathNotifier,
                ),
            ],
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

  Widget _buildPreviousVersion(
    BuildContext context,
    String version,
    bool hasWriteAccess,
    FileReference file,
    PathNotifierState pathNotifier,
  ) {
    final fileData = file.history![version]!;

    final dt = DateTime.fromMillisecondsSinceEpoch(fileData.ts);

    return ListTile(
        leading: SizedBox(
          width: 40,
          child: Center(
            child: Text(
              version,
              style: const TextStyle(
                fontSize: 24,
              ),
            ),
          ),
        ),
        title: Text('${timeago.format(dt)} (${filesize(fileData.cid.size)})'),
        subtitle: Text(formatDateTime(dt)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (devModeEnabled)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: TextButton(
                  onPressed: () async {
                    try {
                      showLoadingDialog(context, 'Unpinning version...');
                      mySky.api.deleteCID(
                        CID(cidTypeRaw,
                            fileData.encryptedCID!.encryptedBlobHash,
                            size: 0),
                      );
                      context.pop();
                    } catch (e, st) {
                      context.pop();
                      showErrorDialog(context, e, st);
                    }
                  },
                  child: const Text(
                    'Unpin',
                  ),
                ),
              ),
            if (hasWriteAccess)
              ElevatedButton(
                onPressed: () async {
                  context.pop();
                  showLoadingDialog(context, 'Restoring version $version...');
                  try {
                    await storageService.dac.updateFile(
                      pathNotifier.toUriString(),
                      file.name,
                      fileData,
                    );

                    context.pop();
                  } catch (e, st) {
                    context.pop();
                    showErrorDialog(context, e, st);
                  }
                },
                child: const Text(
                  'Restore',
                ),
              ),
          ],
        ));
  }
}
