import 'package:clipboard/clipboard.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:vup/app.dart';

class ShareDialog extends StatefulWidget {
  final List<String> directoryUris;
  final List<String> fileUris;
  const ShareDialog({
    this.directoryUris = const [],
    this.fileUris = const [],
    Key? key,
  }) : super(key: key);

  @override
  _ShareDialogState createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  List<String> get directoryUris => widget.directoryUris;
  List<String> get fileUris => widget.fileUris;

  String type = 'static';

  bool _isRunning = false;

  bool _doReEncryptFiles = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Share'),
          if (!_isRunning)
            IconButton(
              onPressed: () {
                context.pop();
              },
              icon: Icon(
                Icons.close,
              ),
            )
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (directoryUris.isNotEmpty) ...[
              Text(
                '${directoryUris.length} directories',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              for (final dir in directoryUris)
                Text(Uri.parse(dir).pathSegments.join('/')),
            ],
            if (fileUris.isNotEmpty) ...[
              Text(
                '${fileUris.length} files',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              for (final file in fileUris)
                Text(Uri.parse(file).pathSegments.join('/')),
            ],
            SizedBox(
              height: 16,
            ),
            Text(
              'Sharing type',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Wrap(
              children: [
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ChoiceChip(
                    label: Text('Static (read-only, no updates)'),
                    selected: type == 'static',
                    onSelected: _isRunning
                        ? null
                        : (_) {
                            setState(
                              () {
                                type = 'static';
                              },
                            );
                          }, // ! Only static allows multiple directories and files (mix and match)
                    // ! You can still add files and directories to the share manually later, but it will not be updated automatically
                  ),
                ),
                /*     Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ChoiceChip(
                    // ! only 1 dir, creates a virtual directory, copies everything there and mounts it
                    label: Text('With Updates (read-only)'),
                    selected: type == 'todo',
                    onSelected: null, // ! also allows single file later
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ChoiceChip(
                    // ! Only works for one directory, is mounted using read-write URL
                    label: Text('Open (read and write)'),
                    selected: type == 'todo',
                    onSelected: null, // ! also allows single file later
                  ),
                ), */
                /*     ChoiceChip(
                    label: Text('Public (with the world)'),
                    selected: type == 'todo',
                    onSelected: null,
                  ), */
              ],
            ),
            /*  if (type == 'static')
              CheckboxListTile(
                value: _doReEncryptFiles,
                onChanged:
                    null /*  _isRunning
                    ? null
                    : (val) {
                        setState(() {
                          _doReEncryptFiles = val!;
                        });
                      } */
                ,
                title: Text('Re-encrypt files (Hard copy)'),
                subtitle: Text(
                  'Requires fully downloading, decrypting, encrypting and re-uploading all shared files.',
                ),
              ), */
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _isRunning
                    ? null
                    : () async {
                        setState(() {
                          _isRunning = true;
                        });
                        try {
                          if (type == 'static') {
                            logger
                                .verbose('Preparing static share operation...');
                            final uuid = Uuid().v4();
                            await storageService.dac.createDirectory(
                              'vup.hns/.internal/shared-static-directories',
                              uuid,
                            );
                            final shareUri = storageService.dac.parsePath(
                                'vup.hns/.internal/shared-static-directories/$uuid');

                            final futures = <Future>[];
                            for (final dirUri in directoryUris) {
                              final parts = storageService.dac.parseFilePath(
                                dirUri,
                              );
                              futures.add(
                                storageService.dac.createDirectory(
                                  shareUri.toString(),
                                  parts.fileName,
                                ),
                              );
                              futures.add(
                                storageService.dac.cloneDirectory(
                                  dirUri,
                                  storageService.dac
                                      .getChildUri(shareUri, parts.fileName)
                                      .toString(),
                                ),
                              );
                            }
                            for (final fileUri in fileUris) {
                              futures.add(
                                storageService.dac.copyFile(
                                  fileUri,
                                  shareUri.toString(),
                                ),
                              );
                            }
                            await Future.wait(futures);
                            final shareSeed =
                                await storageService.dac.getShareUriReadOnly(
                              shareUri.toString(),
                            );

                            final shareLink =
                                'https://share.vup.app/#${shareSeed}';
                            showShareResultDialog(context, shareLink);
                          }
                        } catch (e, st) {
                          showErrorDialog(context, e, st);
                        }
                        setState(() {
                          _isRunning = false;
                        });
                      },
                child: Text(
                  'Start sharing process ',
                ),
              ),
            ),
            if (_isRunning)
              ListTile(
                leading: CircularProgressIndicator(),
                title: Text('Doing things...'),
              )
          ],
        ),
      ),
    );
  }

  void showShareResultDialog(BuildContext context, String shareLink) {
    final qrImage = QrImage(
      data: shareLink,
      version: QrVersions.auto,
      // size: 300.0,
      backgroundColor: Colors.white,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Share link'),
            IconButton(
              onPressed: () {
                context.pop();
              },
              icon: Icon(
                Icons.close,
              ),
            )
          ],
        ),
        content: context.isMobile
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width - 150,
                    height: MediaQuery.of(context).size.width - 150,
                    child: qrImage,
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  Text(shareLink),
                  SizedBox(
                    height: 16,
                  ),
                  ElevatedButton(
                    onPressed: () {
                      FlutterClipboard.copy(
                        shareLink,
                      );
                    },
                    child: Text(
                      'Copy to clipboard',
                    ),
                  )
                ],
              )
            : SizedBox(
                width: 600,
                child: Row(
                  children: [
                    SizedBox(
                      width: 300,
                      height: 300,
                      child: qrImage,
                    ),
                    SizedBox(
                      width: 8,
                    ),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(shareLink),
                          /* Text(
                            'WARNING: Once you shared this link with someone, they will be able to read this directory, all subdirectories and their future changes FOREVER! (A long time!)',
                          ),
                      */
                          SizedBox(
                            height: 16,
                          ),
                          ElevatedButton(
                            onPressed: () {
                              FlutterClipboard.copy(
                                shareLink,
                              );
                            },
                            child: Text(
                              'Copy to clipboard',
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
      barrierDismissible: false,
    );
  }
}
