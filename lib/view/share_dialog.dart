import 'package:clipboard/clipboard.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:vup/app.dart';
import 'package:vup/widget/hint_card.dart';
import 'package:vup/widget/sky_button.dart';

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

  bool _isStatic = true;
  bool _isWithWriteAccess = false;

  bool _isRunning = false;

  bool _advancedSharePossible = false;

  String? currentViewType;

  @override
  void initState() {
    super.initState();
    if (directoryUris.length == 1 && fileUris.isEmpty) {
      _advancedSharePossible = true;
    }
  }

  String renderUri(String uri) {
    final segments = List.from(Uri.parse(uri).pathSegments);

    if (segments.length > 0 && segments.first == 'fs-dac.hns') {
      segments.removeAt(0);
    }
    return segments.join('/');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Share online',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
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
                directoryUris.length == 1
                    ? '1 directory'
                    : '${directoryUris.length} directories',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              for (final dir in directoryUris) Text(renderUri(dir)),
            ],
            if (fileUris.isNotEmpty) ...[
              if (directoryUris.isNotEmpty)
                SizedBox(
                  height: 8,
                ),
              Text(
                '${fileUris.length} files',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              for (final file in fileUris) Text(renderUri(file)),
            ],
            SizedBox(
              height: 16,
            ),
            Text(
              'Sharing type',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            if (!_advancedSharePossible) ...[
              SizedBox(
                height: 8,
              ),
              HintCard(
                icon: UniconsLine.info_circle,
                color: Theme.of(context).primaryColor,
                content: Text(
                  'Your share link will only contain the current version of everything you selected. If you want to share a directory including its future changes or want to allow other users to write to the shared directory, you have to select only one directory.',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
            if (_advancedSharePossible) ...[
              RadioListTile<bool>(
                title: Text('Static (only the current version)'),
                value: true,
                groupValue: _isStatic,
                onChanged: (val) {
                  setState(() {
                    _isStatic = val!;
                  });
                },
              ),
              RadioListTile<bool>(
                title: Text(
                    'With changes (all updates to this directory in the future)'),
                value: false,
                groupValue: _isStatic,
                onChanged: (val) {
                  setState(() {
                    _isStatic = val!;
                  });
                },
              ),
              if (!_isStatic) ...[
                CheckboxListTile(
                  title: Text('Allow writes'),
                  subtitle: Text(
                    'If enabled, any user who knows the share link can not only read but also write to your shared directory.',
                  ),
                  value: _isWithWriteAccess,
                  onChanged: (val) {
                    setState(() {
                      _isWithWriteAccess = val!;
                    });
                  },
                ),
                SizedBox(
                  height: 4,
                ),
                HintCard(
                  icon: UniconsLine.exclamation_octagon,
                  color: SkyColors.warning,
                  content: Text(
                    'It\'s not yet possible to revoke access to directories you shared using the "With changes" mode. This feature will be added in a later version of Vup.',
                    style: TextStyle(
                      color: SkyColors.warning,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
            if (_isStatic && devModeEnabled) ...[
              SizedBox(
                height: 16,
              ),
              Text(
                'View type',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              SizedBox(
                height: 8,
              ),
              Wrap(
                children: [
                  for (final viewType in [
                    ['generic', 'Generic'],
                    ['gallery', 'Gallery'],
                    ['audio', 'Audio'],
                    ['video', 'Video'],
                    ['webamp', 'Webamp'],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(viewType[1]),
                        selected: currentViewType == viewType[0],
                        onSelected: (_) async {
                          setState(() {
                            currentViewType = viewType[0];
                          });
                        },
                      ),
                    ),
                ],
              )
            ],
            if (false)
              Wrap(
                children: [
                  /*     Padding(
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
                ), */
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
            SizedBox(
              height: 16,
            ),
            Padding(
              padding: const EdgeInsets.only(),
              child: SkyButton(
                color: Theme.of(context).primaryColor,
                filled: true,
                enabled: !_isRunning,
                onPressed: _isRunning
                    ? null
                    : () async {
                        setState(() {
                          _isRunning = true;
                        });
                        try {
                          if (_isStatic) {
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
                                  generatePresignedUrls: true,
                                ),
                              );
                            }
                            await Future.wait(futures);
                            final shareSeed =
                                await storageService.dac.getShareUriReadOnly(
                              shareUri.toString(),
                            );

                            final shareLink = _buildShareLink(shareSeed);
                            context.pop();
                            showShareResultDialog(context, shareLink);
                          } else {
                            if (_isWithWriteAccess) {
                              logger.info(
                                  'preparing non-static read+write share operation...');

                              final localUri = storageService.dac.parsePath(
                                directoryUris.first,
                                resolveMounted: false,
                              );

                              final shareUri = await storageService.dac
                                  .generateSharedReadWriteDirectory();

                              await storageService.dac.cloneDirectory(
                                localUri.toString(),
                                shareUri,
                              );

                              await storageService.dac.mountUri(
                                localUri.toString(),
                                Uri.parse(shareUri),
                              );

                              final shareLink = _buildShareLink(shareUri);
                              context.pop();
                              showShareResultDialog(context, shareLink);
                            } else {
                              logger.info(
                                  'preparing non-static read-only share operation...');

                              final dirUri = storageService.dac
                                  .parsePath(directoryUris.first);

                              final sharedDirectoriesUri = storageService.dac
                                  .parsePath(
                                      'vup.hns/.internal/shared-directories');

                              final res = await storageService.dac
                                  .doOperationOnDirectory(
                                sharedDirectoriesUri,
                                (directoryIndex) async {
                                  directoryIndex
                                          .directories[dirUri.toString()] =
                                      DirectoryDirectory(
                                    name: dirUri.pathSegments.isEmpty
                                        ? 'RW share URI'
                                        : dirUri.pathSegments.last,
                                    created:
                                        DateTime.now().millisecondsSinceEpoch,
                                  );
                                },
                              );

                              if (!res.success) throw res.error.toString();

                              final shareSeed =
                                  await storageService.dac.getShareUriReadOnly(
                                dirUri.toString(),
                              );

                              final shareLink = _buildShareLink(shareSeed);
                              context.pop();
                              showShareResultDialog(context, shareLink);
                            }
                          }
                        } catch (e, st) {
                          showErrorDialog(context, e, st);
                        }
                        if (mounted) {
                          setState(() {
                            _isRunning = false;
                          });
                        }
                      },
                label: 'Start sharing process',
              ),
            ),
            if (_isRunning)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: ListTile(
                  leading: CircularProgressIndicator(),
                  title: Text('Generating share link...'),
                ),
              )
          ],
        ),
      ),
    );
  }

  String _buildShareLink(String shareSeed) {
    if (currentViewType == null || currentViewType == 'generic') {
      return 'https://share.vup.app/#${shareSeed}';
    } else {
      if (currentViewType == 'gallery') {
        return 'https://0406jckksspiqk11ivr641v1q09paul9bufdufl4svm50kjutvvjio8.${mySky.skynetClient.portalHost}/#${shareSeed}?viewType=$currentViewType';
      } else {
        return 'https://mstream.hns.${mySky.skynetClient.portalHost}/#${shareSeed}?viewType=$currentViewType';
      }
    }
  }
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
