import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_chromecast/casting/cast.dart';
import 'package:dart_chromecast/utils/mdns_find_chromecast.dart'
    as find_chromecast;
import 'package:clipboard/clipboard.dart';
import 'package:context_menus/context_menus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:filesize/filesize.dart';
import 'package:filesystem_dac/dac.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_state_notifier/flutter_state_notifier.dart';
import 'package:path/path.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:vup/app.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:open_file/open_file.dart';
import 'package:vup/main.dart';
import 'package:vup/utils/date_format.dart';
import 'package:vup/utils/pin.dart';
import 'package:vup/view/file_details_dialog.dart';
import 'package:vup/view/share_dialog.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';

class FileSystemEntityWidget extends StatefulWidget {
  final dynamic _entity;

  final PathNotifierState pathNotifier;
  final DirectoryViewState viewState;

  ZoomLevel get zoomLevel => viewState.zoomLevel;

  const FileSystemEntityWidget(
    this._entity, {
    Key? key,
    required this.pathNotifier,
    required this.viewState,
  }) : super(key: key);

  @override
  State<FileSystemEntityWidget> createState() => _FileSystemEntityWidgetState();
}

class _FileSystemEntityWidgetState extends State<FileSystemEntityWidget> {
  bool get isDirectory => widget._entity is DirectoryDirectory;

  DirectoryDirectory get dir => widget._entity;

  DirectoryFile get file => widget._entity;

  StreamSubscription? sub;

  final focusNode = FocusNode();

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  bool enabled = true;

  bool get isUploading => (!isDirectory && file.file.url.isEmpty);
  bool get isInTrash =>
      (widget.pathNotifier.path.length >= 2) &&
      widget.pathNotifier.path[1] == '.trash';

  bool get isSharePossible => widget.pathNotifier.value.length > 1;

  var lastClickTime = DateTime(0);

  @override
  Widget build(BuildContext context) {
    final textColor = isUploading ? Theme.of(context).hintColor : null;

    final uri = widget._entity.uri;

    // print('uri $uri');

    final isSelected = isDirectory
        ? widget.pathNotifier.selectedDirectories.contains(uri)
        : widget.pathNotifier.selectedFiles.contains(uri);

    bool isTreeSelected = false;
    if (columnViewActive && isDirectory) {
      final customURI = /* widget.pathNotifier.getChildUri( */ widget
          ._entity.uri /* ) */;
      /* print(appLayoutState.currentTab.last.state.toUri());
      print(customURI); */
      if (appLayoutState.currentTab.last.state
          .toUriString()
          .startsWith(customURI)) {
        isTreeSelected = true;
      }
    }
    final hasWriteAccess = storageService.dac
            .checkAccess(widget.pathNotifier.toCleanUri().toString()) &&
        !isInTrash;

    return ContextMenuRegion(
      contextMenu: GenericContextMenu(
        buttonStyle: ContextMenuButtonStyle(
          hoverFgColor: Theme.of(context).colorScheme.secondary,
        ),
        buttonConfigs: [
          if (isDirectory) ...[
            ContextMenuButtonConfig(
              "Open in new tab",
              onPressed: () {
                final newPathNotifier = PathNotifierState([]);
                if (dir.uri?.startsWith('skyfs://') ?? false) {
                  final uri = Uri.parse(dir.uri!);

                  newPathNotifier.queryParamaters = Map.from(
                    uri.queryParameters,
                  );

                  if (uri.host == 'local') {
                    newPathNotifier.path = uri.pathSegments.sublist(1);
                  } else {
                    newPathNotifier.path = [dir.uri!];
                  }
                } else {
                  newPathNotifier.value = [
                    ...widget.pathNotifier.value,
                    dir.name
                  ];
                }
                appLayoutState.createTab(
                  initialState: AppLayoutViewState(newPathNotifier),
                );
              },
            ),
          ],
          ContextMenuButtonConfig(
            isSelected ? 'Unselect...' : 'Select...',
            onPressed: () async {
              setState(() {
                if (isDirectory) {
                  if (isSelected) {
                    widget.pathNotifier.selectedDirectories.remove(uri);
                    widget.pathNotifier.$();
                  } else {
                    widget.pathNotifier.selectedDirectories.add(uri);
                    widget.pathNotifier.$();
                  }
                } else {
                  if (isSelected) {
                    widget.pathNotifier.selectedFiles.remove(uri);
                    widget.pathNotifier.$();
                  } else {
                    widget.pathNotifier.selectedFiles.add(uri);
                    widget.pathNotifier.$();
                  }
                }
              });
            },
          ),
          /* ContextMenuButtonConfig(
            "Select files...",
            onPressed: () async {
              showDialog(
                context: context,
                builder: (context) => ShareDialog(
                  filePaths: [
                    (widget.pathNotifier.value + [file.name]).join('/'),
                  ],
                ),
                barrierDismissible: false,
              );
            },
          ), */
          if (isDirectory) ...[
            if (hasWriteAccess) ...[
              ContextMenuButtonConfig(
                "Rename directory",
                onPressed: () async {
                  final ctrl = TextEditingController(text: dir.name);
                  final name = await showDialog<String?>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Rename your directory'),
                      content: TextField(
                        controller: ctrl,
                        autofocus: true,
                        onSubmitted: (value) => context.pop(value),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => context.pop(),
                          child: Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => context.pop(ctrl.text),
                          child: Text('Rename'),
                        ),
                      ],
                    ),
                  );

                  if (name != null) {
                    showLoadingDialog(context, 'Renaming directory...');
                    try {
                      final res = await storageService.dac.moveDirectory(
                        uri,
                        storageService.dac
                            .getChildUri(
                              storageService.dac.parsePath(
                                  widget.pathNotifier.path.join('/')),
                              name.trim(),
                            )
                            .toString(),
                      );
                      if (!res.success) throw res.error!;
                      context.pop();
                    } catch (e, st) {
                      context.pop();
                      showErrorDialog(context, e, st);
                    }
                  }
                },
              ),
            ],
            if (!sidebarService
                .isPinned([...widget.pathNotifier.path, dir.name].join('/')))
              ContextMenuButtonConfig(
                "Add to Quick Access",
                onPressed: () async {
                  showLoadingDialog(context, 'Adding to Quick Access...');
                  try {
                    await sidebarService.pinDirectory(
                      [...widget.pathNotifier.path, dir.name].join('/'),
                    );
                    context.pop();
                  } catch (e, st) {
                    context.pop();
                    showErrorDialog(context, e, st);
                  }
                },
              ),
            ContextMenuButtonConfig(
              "Pin all",
              onPressed: () async {
                await pinAll(
                  context,
                  dir.uri!,
                );
              },
            ),
            if (widget.pathNotifier.value.length > 0)
              ContextMenuButtonConfig(
                "Share directory",
                onPressed: () async {
                  showDialog(
                    context: context,
                    builder: (context) => ShareDialog(
                      directoryUris: [
                        uri,
                      ],
                    ),
                    barrierDismissible: false,
                  );
                },
              ),
            if (hasWriteAccess) ...[
              ContextMenuButtonConfig(
                isInTrash ? 'Delete permanently' : "Move to trash",
                onPressed: () async {
                  try {
                    if (isInTrash) {
                      showLoadingDialog(
                          context, 'Deleting directory permanently...');
                      await storageService.dac.deleteDirectoryRecursive(
                        dir.uri!,
                      );
                      final path = storageService.dac.parseFilePath(dir.uri!);
                      await storageService.dac.deleteDirectory(
                        path.directoryPath,
                        path.fileName,
                      );
                    } else {
                      showLoadingDialog(
                          context, 'Moving directory to trash...');
                      // TODO Generate random key
                      await storageService.dac.moveDirectory(
                        uri,
                        storageService.trashPath + '/' + dir.name,
                        // generateRandomKey: true,
                      );
                    }
                    context.pop();
                  } catch (e, st) {
                    context.pop();
                    showErrorDialog(context, e, st);
                  }
                },
              ),
              if (devModeEnabled)
                ContextMenuButtonConfig(
                  "Copy SkyFS URI (Debug)",
                  onPressed: () async {
                    FlutterClipboard.copy(dir.uri!);
                  },
                ),
              /*   ContextMenuButtonConfig(
                "Delete directory",
                onPressed: () async {
                  showLoadingDialog(context, 'Removing folder...');
                  try {
                    final res = await storageService.dac.deleteDirectory(
                      widget.pathNotifier.value.join('/'),
                      dir.name,
                    );
                    if (!res.success) throw res.error!;
                    context.pop();
                  } catch (e, st) {
                    context.pop();
                    showErrorDialog(context, e, st);
                  }
                },
              ), */
            ]
          ],
          if (!isDirectory) ...[
            if (isWebServerEnabled)
              ContextMenuButtonConfig(
                "Copy Web Server URL",
                onPressed: () async {
                  FlutterClipboard.copy(
                    Uri(
                      scheme: 'http',
                      host: '127.0.0.1',
                      port: webServerPort,
                      pathSegments:
                          Uri.parse(file.uri!).pathSegments.sublist(1),
                    ).toString(),
                  );
                },
              ),
            ContextMenuButtonConfig(
              "Copy temporary streaming link",
              onPressed: () async {
                FlutterClipboard.copy(
                  await temporaryStreamingServerService.makeFileAvailable(file),
                );
              },
            ),
            if (hasWriteAccess) ...[
              ContextMenuButtonConfig(
                "Rename file",
                onPressed: () async {
                  final ctrl = TextEditingController(text: file.name);
                  final name = await showDialog<String?>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Rename your file'),
                      content: TextField(
                        controller: ctrl,
                        autofocus: true,
                        onSubmitted: (value) => context.pop(value),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => context.pop(),
                          child: Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => context.pop(ctrl.text),
                          child: Text('Rename'),
                        ),
                      ],
                    ),
                  );

                  if (name != null) {
                    showLoadingDialog(context, 'Renaming file...');
                    try {
                      final res = await storageService.dac.renameFile(
                        uri,
                        name,
                      );
                      if (!res.success) throw res.error!;
                      context.pop();
                    } catch (e, st) {
                      context.pop();
                      showErrorDialog(context, e, st);
                    }
                  }
                },
              ),
            ],
            ContextMenuButtonConfig(
              "Share file (Online)",
              onPressed: () async {
                showDialog(
                  context: context,
                  builder: (context) => ShareDialog(
                    fileUris: [
                      uri,
                    ],
                  ),
                  barrierDismissible: false,
                );
              },
            ),
            ContextMenuButtonConfig(
              "Save file locally",
              onPressed: () async {
                if (!enabled) return;

                String? path;
                if (Platform.isAndroid || Platform.isIOS) {
                  path = await FilePicker.platform.saveFile(
                    fileName: file.name,
                  );
                } else {
                  path = await FileSelectorPlatform.instance.getSavePath(
                    suggestedName: file.name,
                  );
                }

                if (path != null) {
                  final localFile = File(path);
                  /* showLoadingDialog(
                        context, 'Downloading and saving file...'); */
                  await downloadPool.withResource(
                    () => storageService.downloadAndDecryptFile(
                      fileData: file.file,
                      name: file.name,
                      outFile: localFile,
                      created: file.created,
                      modified: file.modified,
                    ),
                  );
                  // context.pop();
                  // showInfoDialog(context, 'File saved successfully', '');
                }

                // FilePicker.platform.saveFile()
              },
            ),
            if (devModeEnabled)
              ContextMenuButtonConfig(
                'Stream to Cast device',
                onPressed: () async {
                  if (Platform.isAndroid) {
                    await requestAndroidBackgroundPermissions();
                  }
                  showLoadingDialog(context,
                      'Seaching for Cast devices in your local network...');

                  final streamUrl = await temporaryStreamingServerService
                      .makeFileAvailable(file);

                  List<find_chromecast.CastDevice> devices =
                      await find_chromecast.find_chromecasts();
                  print(devices);
                  context.pop();
                  if (devices.length == 0) {
                    showInfoDialog(
                      context,
                      'No Cast devices found',
                      'No devices with Cast support were found on your local network.',
                    );
                    return;
                  }
                  final find_chromecast.CastDevice? selectedDevice =
                      await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                                title: Text('Choose a Cast device'),
                                content: SizedBox(
                                  height: dialogHeight,
                                  width: dialogWidth,
                                  child: ListView(
                                    children: [
                                      for (final d in devices)
                                        ListTile(
                                          title: Text('${d.ip}:${d.port}'),
                                          subtitle: Text('${d.name}'),
                                          onTap: () => context.pop(d),
                                        ),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => context.pop(),
                                    child: Text(
                                      'Cancel',
                                    ),
                                  ),
                                ],
                              ));

                  if (selectedDevice != null) {
                    final CastSender castSender = CastSender(
                      CastDevice(
                        name: selectedDevice.name,
                        host: selectedDevice.ip,
                        port: selectedDevice.port,
                        type: '_googlecast._tcp',
                      ),
                    );

                    castSender.castSessionController.stream
                        .listen((CastSession? castSession) async {
                      if (castSession!.isConnected) {
                        print('cast state ${castSession.toMap()}');
                      }
                    });

                    CastMediaStatus? prevMediaStatus;
                    // Listen for media status updates, such as pausing, playing, seeking, playback etc.
                    castSender.castMediaStatusController.stream
                        .listen((CastMediaStatus? mediaStatus) {
                      // show progress for example
                      if (mediaStatus == null) {
                        return;
                      }
                      if (null != prevMediaStatus &&
                          mediaStatus.volume != prevMediaStatus!.volume) {
                        print('Volume just updated to ${mediaStatus.volume}');
                      }
                      if (null == prevMediaStatus ||
                          mediaStatus.position != prevMediaStatus?.position) {
                        print('Media Position is ${mediaStatus.position}');
                      }
                      prevMediaStatus = mediaStatus;
                    });

                    bool connected = false;
                    bool didReconnect = false;

                    /*    if (null != savedState) {
                      connected = await castSender.reconnect(
                        sourceId: savedState['sourceId'],
                        destinationId: savedState['destinationId'],
                      );
                      if (connected) {
                        didReconnect = true;
                      }
                    } */
                    if (!connected) {
                      connected = await castSender.connect();
                    }

                    if (!connected) {
                      print('COULD NOT CONNECT!');
                      return;
                    }
                    print("Connected with device");

                    if (!didReconnect) {
                      castSender.launch();
                    }

                    castSender.loadPlaylist([
                      CastMedia(
                        contentId: streamUrl,
                        contentType:
                            file.mimeType ?? 'application/octet-stream',
                        autoPlay: true,
                        title: file.name,
                      ),
                    ], append: false);

                    // Initiate key press handler
                    // space = toggle pause
                    // s = stop playing
                    // left arrow = seek current playback - 10s
                    // right arrow = seek current playback + 10s
                    // up arrow = volume up 5%
                    // down arrow = volume down 5%
                    /* stdin.echoMode = false;
                    stdin.lineMode = false; */

                    /* stdin.asBroadcastStream().listen((List<int> data) {
                      _handleUserInput(castSender, data);
                    }); */
                  }

                  /*   void _handleUserInput(CastSender castSender, List<int> data) {
                    if (data.length == 0) return;

                    int keyCode = data.last;

                    log.info("pressed key with key code: ${keyCode}");

                    if (32 == keyCode) {
                      // space = toggle pause
                      castSender.togglePause();
                    } else if (115 == keyCode) {
                      // s == stop
                      castSender.stop();
                    } else if (27 == keyCode) {
                      // escape = disconnect
                      castSender.disconnect();
                    } else if (65 == keyCode) {
                      // up
                      double? volume =
                          castSender.castSession?.castMediaStatus?.volume;
                      if (volume != null) {
                        castSender.setVolume(min(1, volume + 0.1));
                      }
                    } else if (66 == keyCode) {
                      // down
                      double? volume =
                          castSender.castSession?.castMediaStatus?.volume;
                      if (volume != null) {
                        castSender.setVolume(max(0, volume - 0.1));
                      }
                    } else if (67 == keyCode || 68 == keyCode) {
                      // left or right = seek 10s back or forth
                      double seekBy = 67 == keyCode ? 10.0 : -10.0;
                      if (null != castSender.castSession &&
                          null != castSender.castSession!.castMediaStatus) {
                        castSender.seek(
                          max(
                              0.0,
                              castSender
                                      .castSession!.castMediaStatus!.position! +
                                  seekBy),
                        );
                      }
                    } */

                  /*    final results = await CastDiscoveryService().search();
                  print('results $results');
                  
                  final session =
                      await CastSessionManager().startSession(results[0]);

                  session.stateStream.listen((state) {
                    print('state $state');
                    if (state == CastSessionState.connected) {
                      session.sendMessage(CastSession.kNamespaceMedia, {
                        'type': 'LOAD',
                        'autoplay': true,
                        'currentTime': 0,
                        'media': {
                          "contentId": streamUrl,
                          // "streamType": 'BUFFERED',
                          "contentType": 'video/mp4',
                        }
                        // 'appId': 'YT', // set the appId of your app here
                      });
                    }
                  });

                  session.messageStream.listen((message) {
                    print('receive message: $message');
                  });

                  session.sendMessage(CastSession.kNamespaceReceiver, {
                    'type': 'LAUNCH',
                    'appId': 'CC1AD845', // set the appId of your app here
                  }); */
                },
              ),
            if (!(UniversalPlatform.isLinux || UniversalPlatform.isWindows))
              ContextMenuButtonConfig(
                "Share file with other app",
                onPressed: () async {
                  if (!enabled) return;
                  final link = await downloadPool.withResource(
                    () => storageService.downloadAndDecryptFile(
                      fileData: file.file,
                      name: file.name,
                      outFile: null,
                    ),
                  );

                  Share.shareFiles([link]);
                },
              ),
            if (!localFiles.containsKey(file.file.hash))
              ContextMenuButtonConfig(
                "Make available offline",
                onPressed: () async {
                  if (!enabled) return;
                  setState(() {
                    enabled = false;
                  });
                  try {
                    await downloadPool.withResource(
                      () => storageService.downloadAndDecryptFile(
                        fileData: file.file,
                        name: file.name,
                        outFile: null,
                      ),
                    );
                  } catch (e, st) {
                    print(e);
                    print(st);
                    showErrorDialog(context, e, st);
                  }
                  if (mounted) {
                    setState(() {
                      enabled = true;
                    });
                  }
                },
              ),
            if (hasWriteAccess)
              ContextMenuButtonConfig(
                'Re-generate metadata',
                onPressed: () async {
                  try {
                    final link = await downloadPool.withResource(
                      () => storageService.downloadAndDecryptFile(
                        fileData: file.file,
                        name: file.name,
                        outFile: null,
                      ),
                    );
                    final fileData =
                        await storageService.startFileUploadingTask(
                      'vup.hns',
                      File(link),
                      metadataOnly: true,
                    );
                    logger.verbose(fileData);
                    await storageService.dac.updateFileExtensionData(
                      file.uri!,
                      fileData!.ext,
                    );

                    storageService.dac
                        .getFileStateChangeNotifier(fileData.hash)
                        .updateFileState(
                          FileState(
                            type: FileStateType.idle,
                            progress: 0,
                          ),
                        );
                  } catch (e, st) {
                    showErrorDialog(context, e, st);
                  }
                },
              ),
            if (localFiles.containsKey(file.file.hash))
              ContextMenuButtonConfig(
                'Delete from device',
                onPressed: () async {
                  final hash = file.file.hash;
                  final decryptedFile = File(join(
                    storageService.dataDirectory,
                    'local_files',
                    hash,
                    file.name,
                  ));
                  await decryptedFile.delete();
                  localFiles.delete(hash);
                  setState(() {});
                },
              ),
            if (hasWriteAccess) ...[
              ContextMenuButtonConfig(
                isInTrash ? 'Delete permanently' : "Move to trash",
                onPressed: () async {
                  try {
                    if (isInTrash) {
                      showLoadingDialog(
                          context, 'Deleting file permanently...');
                      await storageService.dac.deleteFile(
                        uri,
                      );
                    } else {
                      showLoadingDialog(context, 'Moving file to trash...');
                      await storageService.dac.moveFile(
                        uri,
                        storageService.trashPath + '/' + file.name,
                        generateRandomKey: true,
                      );
                    }
                    context.pop();
                  } catch (e, st) {
                    showErrorDialog(context, e, st);
                  }
                },
              ),
            ],
            if (file.version > 0)
              ContextMenuButtonConfig(
                "Previous versions",
                onPressed: () async {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Previous versions'),
                      content: SizedBox(
                        width: dialogWidth,
                        height: dialogHeight,
                        child: ListView(
                          children: [
                            for (final version
                                in (file.history ?? {}).keys.toList().reversed)
                              _buildPreviousVersion(
                                context,
                                version,
                                hasWriteAccess,
                              ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => ctx.pop(),
                          child: Text(
                            'Close',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ContextMenuButtonConfig(
              'Details',
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('File details'),
                    content: SizedBox(
                      width: dialogWidth,
                      height: dialogHeight,
                      child: FileDetailsDialog(
                        file,
                        hasWriteAccess: hasWriteAccess,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => ctx.pop(),
                        child: Text(
                          'Close',
                        ),
                      ),
                    ],
                  ),
                );
                setState(() {});
              },
            ),
            if (devModeEnabled)
              ContextMenuButtonConfig(
                "Copy SkyFS URI (Debug)",
                onPressed: () async {
                  FlutterClipboard.copy(file.uri!);
                },
              ),
            if (devModeEnabled)
              //
              ContextMenuButtonConfig(
                "View JSON (Debug)",
                onPressed: () async {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('JSON Metadata'),
                      content: SizedBox(
                        width: dialogWidth,
                        height: dialogHeight,
                        child: SingleChildScrollView(
                          reverse: true,
                          child: SelectableText(
                            JsonEncoder.withIndent('  ').convert(
                              file,
                            ),
                            /* language: 'json',
                            theme: draculaTheme,
                            padding: EdgeInsets.all(12), */
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ],
      ),
      child: InkWell(
        /*  onDoubleTap: () {
            print('onDoubleTap');
          }, */
        focusNode: focusNode,
        // TODO Use for flexible drag n' drop
        /* onHover: (value) {
          print('onHover $value');
        }, */
        onTap: (!enabled || isUploading)
            ? null
            : () async {
                // final FocusNode focusNode = Focus.of(context);

                if (!focusNode.hasFocus) {
                  focusNode.requestFocus();
                }

                /* if (isShiftPressed) {
                  return;
                  // TODO Create local selectThis and unselectThis methods
                  // TODO get list index from parent
                } */

                bool skipAllowed = true;
                if (isDoubleClickToOpenEnabled) {
                  final now = DateTime.now();

                  if (now.difference(lastClickTime).inMilliseconds < 500) {
                    // print('detected double-click');
                    skipAllowed = false;
                    if (widget.pathNotifier.isInSelectionMode) {
                      widget.pathNotifier.selectedDirectories.clear();
                      widget.pathNotifier.selectedFiles.clear();
                      widget.pathNotifier.$();
                    }
                  } else {
                    // lastClickTime = now;
                    // return;
                  }
                  lastClickTime = now;
                }

                if (isDoubleClickToOpenEnabled && !isControlPressed) {
                  if (widget.pathNotifier.isInSelectionMode) {
                    widget.pathNotifier.selectedDirectories.clear();
                    widget.pathNotifier.selectedFiles.clear();
                    widget.pathNotifier.$();
                  }
                  // skipAllowed = true;
                }

                /*  if (isControlPressed) {
                    skipAllowed = false;
                  } */

                if (skipAllowed &&
                    (widget.pathNotifier.isInSelectionMode ||
                        isControlPressed /* ||
                        isDoubleClickToOpenEnabled */ /*  ||
                          isDoubleClickToOpenEnabled */
                    )) {
                  /*     if (isDoubleClickToOpenEnabled) {
                    return;
                  } */
                  bool changed = true;
                  if (isDirectory) {
                    if (isSelected /* && !isDoubleClickToOpenEnabled */) {
                      widget.pathNotifier.selectedDirectories.remove(uri);
                      widget.pathNotifier.$();
                    } else {
                      final ownPath =
                          [...widget.pathNotifier.value, dir.name].join('/');
                      for (final path
                          in widget.pathNotifier.selectedDirectories) {
                        /* print(path);
                        print(ownPath); */
                        if (path.startsWith(ownPath)) {
                          changed = false;
                          break;
                        }
                      }
                      if (changed) {
                        widget.pathNotifier.selectedDirectories.add(uri);
                        widget.pathNotifier.$();
                      }
                    }
                  } else {
                    if (isSelected /* && !isDoubleClickToOpenEnabled */) {
                      widget.pathNotifier.selectedFiles.remove(uri);
                      widget.pathNotifier.$();
                    } else {
                      widget.pathNotifier.selectedFiles.add(uri);
                      widget.pathNotifier.$();
                    }
                  }
                  if (changed) {
                    setState(() {});
                    return;
                  }
                } else if (skipAllowed && isDoubleClickToOpenEnabled) {
                  return;
                }
                if (isDirectory) {
                  if (columnViewActive) {
                    final newPath = widget.pathNotifier.path +
                        [
                          dir.name,
                        ];
                    var firstIndex = widget.pathNotifier.columnIndex + 1;
                    for (int i = firstIndex;
                        i < appLayoutState.currentTab.length;
                        i++) {
                      appLayoutState.currentTab[i].state.noPathSelected = true;
                      appLayoutState.currentTab[i].state.value = newPath;
                    }
                    if (firstIndex >= appLayoutState.currentTab.length) {
                      firstIndex--;
                      for (int i = 0; i < firstIndex; i++) {
                        final state = appLayoutState.currentTab[i];
                        final childState = appLayoutState.currentTab[i + 1];

                        state.state.noPathSelected =
                            childState.state.noPathSelected;
                        state.state.value = childState.state.path;
                      }
                    }
                    final state = appLayoutState.currentTab[firstIndex].state;
                    state.noPathSelected = false;
                    state.value = newPath;
                    // setState(() {});
                    // TODO Make this more efficient
                    appLayoutState.$();

                    return;
                  }
                  if (dir.uri?.startsWith('skyfs://') ?? false) {
                    final uri = Uri.parse(dir.uri!);

                    widget.pathNotifier.disableSearchMode();
                    widget.pathNotifier.queryParamaters = Map.from(
                      uri.queryParameters,
                    );

                    if (uri.host == 'local') {
                      widget.pathNotifier.path = uri.pathSegments.sublist(1);

                      widget.pathNotifier.$();
                    } else {
                      widget.pathNotifier.path = [dir.uri!];

                      widget.pathNotifier.$();
                    }
                  } else {
                    widget.pathNotifier.value = [
                      ...widget.pathNotifier.value,
                      dir.name
                    ];
                  }
                } else if (!isDirectory) {
                  setState(() {
                    enabled = false;
                  });
                  try {
                    // print(json.encode(file.file));
                    final link = await downloadPool.withResource(
                      () => storageService.downloadAndDecryptFile(
                        fileData: file.file,
                        name: file.name,
                        outFile: null,
                      ),
                    );
                    if (mounted) {
                      setState(() {});
                    }
                    // print(link);

                    final ext = extension(file.name).toLowerCase();

                    if (supportedAudioExtensionsForPlayback.contains(ext) &&
                        !(Platform.isWindows || Platform.isLinux)) {
                      logger.info('use audioPlayer');
                      audioPlayer.pause();

                      audioPlayer.setFilePath(link);
                      audioPlayer.play();
                    } else {
                      OpenFile.open(
                        link,
                        type: file.mimeType,
                      );
                      if (isWatchOpenedFilesEnabled &&
                          sub == null &&
                          file.file.size < (16 * 1000 * 1000)) {
                        final localFile = File(link);
                        var lastModified = localFile.lastModifiedSync();

                        sub = Stream.periodic(Duration(seconds: 5))
                            .listen((event) {
                          if (!isWatchOpenedFilesEnabled ||
                              !localFile.existsSync()) {
                            sub?.cancel();
                            sub = null;
                            return;
                          }
                          if (localFile.lastModifiedSync() != lastModified) {
                            lastModified = localFile.lastModifiedSync();

                            storageService.startFileUploadingTask(
                              widget.pathNotifier.value.join('/'),
                              localFile,
                              create: false,
                              modified: lastModified.millisecondsSinceEpoch,
                            );
                          }
                        });
                      }
                    }
                  } catch (e, st) {
                    print(e);
                    print(st);
                    showErrorDialog(context, e, st);
                  }
                  if (mounted) {
                    setState(() {
                      enabled = true;
                    });
                  }
                }
              },
        child: Container(
          decoration: BoxDecoration(
            border: isTreeSelected
                ? Border(
                    right: BorderSide(
                    color: Theme.of(context).colorScheme.secondary,
                    width: 8,
                  )
                    // width: 2,
                    )
                : null,
            color: isSelected
                ? Theme.of(context).colorScheme.secondary.withOpacity(0.4)
                : Colors.transparent,
          ),
          child: _buildContent(textColor),
        ),
      ),
    );
  }

  Widget _buildPreviousVersion(
      BuildContext context, String version, bool hasWriteAccess) {
    final fileData = file.history![version]!;

    final dt = DateTime.fromMillisecondsSinceEpoch(fileData.ts);

    return ListTile(
      leading: SizedBox(
        width: 40,
        child: Center(
          child: Text(
            version,
            style: TextStyle(
              fontSize: 24,
            ),
          ),
        ),
      ),
      title: Text('${timeago.format(dt)} (${filesize(fileData.size)})'),
      subtitle: Text(formatDateTime(dt)),
      trailing: !hasWriteAccess
          ? null
          : ElevatedButton(
              onPressed: () async {
                context.pop();
                showLoadingDialog(context, 'Restoring version $version...');
                try {
                  await storageService.dac.updateFile(
                    widget.pathNotifier.toUriString(),
                    file.name,
                    fileData,
                  );

                  context.pop();
                } catch (e, st) {
                  context.pop();
                  showErrorDialog(context, e, st);
                }
              },
              child: Text(
                'Restore',
              ),
            ),
    );
  }

  Widget _buildContent(Color? textColor) {
    if (widget.zoomLevel.type == ZoomLevelType.gridCover && !isDirectory) {
      if ((file.ext ?? {}).containsKey('thumbnail'))
        return ThumbnailCoverWidget(
          file: file,
        );
    }

    final stateNotifier = storageService.dac.getFileStateChangeNotifier(
      isDirectory
          ? [...widget.pathNotifier.value, dir.name].join('/')
          : file.file.hash,
    );

    if (widget.zoomLevel.type != ZoomLevelType.list) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIconWidget(
                widget.zoomLevel.size,
                isWidth: false,
              ),
              SizedBox(
                height: widget.zoomLevel.size / 4,
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.zoomLevel.size * 0.1,
                ),
                child: Text(
                  widget._entity.name + '\n\n',
                  textAlign: TextAlign.center,
                  overflow:
                      TextOverflow.ellipsis, // TODO Add fade option in config
                  maxLines: 3,
                  style: TextStyle(
                    fontSize: widget.zoomLevel.size * 0.23,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          StateNotifierBuilder<FileState>(
              stateNotifier: stateNotifier,
              builder: (context, state, _) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: widget.zoomLevel.size * 0.3,
                    top: widget.zoomLevel.size * 0.2,
                    left: widget.zoomLevel.size * 0.3,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (state.type != FileStateType.idle) ...[
                        Icon(
                          iconMap[state.type],
                          size: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        SizedBox(
                          width: 8,
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: state.progress,
                          ),
                        ),
                        /* 
                        SizedBox(
                          width: 8,
                        ), */
                        if (false)
                          InkWell(
                            onTap: () {
                              // TODO stateNotifier.cancel();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(
                                UniconsLine.times,
                                size: 16,
                              ),
                            ),
                          )
                      ],
                      if (!isDirectory &&
                          localFiles.containsKey(file.file.hash)) ...[
                        Icon(
                          UniconsLine.check_circle,
                          size: widget.zoomLevel.size * 0.23,
                          color: context.theme.colorScheme.secondary,
                        ),
                      ]
                    ],
                  ),
                );

                return SizedBox();
              }),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.all(
        widget.zoomLevel.sizeValue == 0 ? 0 : widget.zoomLevel.size * 0.13,
      ),
      child: LayoutBuilder(builder: (context, cons) {
        // TODO Check performance
        return Row(
          children: [
            SizedBox(
              width: widget.zoomLevel.size / 8,
            ),
            _buildIconWidget(widget.zoomLevel.size),
            if (widget.zoomLevel.type == ZoomLevelType.list) ...[
              SizedBox(
                width: widget.zoomLevel.size / 4,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget._entity.name,
                      style: TextStyle(
                        fontSize: widget.zoomLevel.sizeValue == 0
                            ? 14
                            : widget.zoomLevel.size / 2,
                        color: textColor,
                      ),
                    ),
                    /* Text(
                      '${widget._entity.uri}',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.caption!.color,
                        fontSize: 13,
                      ),
                    ), */
                    if (!isDirectory &&
                        file.ext != null &&
                        (file.ext!.containsKey('audio') ||
                            file.ext!.containsKey('video') ||
                            file.ext!.containsKey('image') ||
                            file.ext!.containsKey('publication'))) ...[
                      Text.rich(
                        TextSpan(
                          children: file.ext!.containsKey('image')
                              ? renderImageMetadata(file.ext, context)
                              : file.ext!.containsKey('publication')
                                  ? renderPublicationMetadata(
                                      file.ext?['publication'], context)
                                  : renderAudioMetadata(
                                      file.ext!['audio'] ?? file.ext!['video'],
                                      context),
                        ),
                        style: TextStyle(
                          color: Theme.of(context).textTheme.caption!.color,
                          fontSize: 13,
                        ),
                      ),

                      /*     for (final key in file.ext!['audio'].keys)
                        if (displayedAudioKeys.contains(key))
                          Text(
                              '${audioKeyDisplayNames[key] ?? key}: ${file.ext!['audio'][key]}'),
                      if (file.ext!['audio']['duration'] != null)
                        Text(
                            'Duration: ${renderDuration(file.ext!['audio']['duration'])}'), */
                    ],
                    StateNotifierBuilder<FileState>(
                      stateNotifier: stateNotifier,
                      builder: (context, state, _) {
                        if (state.type == FileStateType.idle) {
                          return SizedBox();
                        }

                        return Row(
                          children: [
                            Icon(
                              iconMap[state.type],
                              size: 16,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            SizedBox(
                              width: 4,
                            ),
                            /*    if (state.progress != null)
                              SizedBox(
                                width: 54,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${(state.progress! * 100).toStringAsFixed(1)} %',
                                  ),
                                ),
                              ),
                            SizedBox(
                              width: 2,
                            ), */
                            Flexible(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: 150),
                                child: LinearProgressIndicator(
                                  value: state.progress,
                                  minHeight: 8,
                                  backgroundColor:
                                      Theme.of(context).dividerColor,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 2,
                            ),
                            if (false)
                              InkWell(
                                onTap: () {
                                  // TODO stateNotifier.cancel();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: Icon(
                                    UniconsLine.times,
                                    size: 16,
                                  ),
                                ),
                              ),
                            /*  Expanded(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: 10),
                                child: LinearProgressIndicator(
                                  value: state.progress,
                                ),
                              ),
                            ), */
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              ...buildMeta(
                context,
                textColor,
                cons.maxWidth > 650,
              ),
            ]
          ],
        );
      }),
    );
  }

  Widget _buildIconWidget(double iconSize, {bool isWidth = true}) {
    if (!isDirectory) {
      if ((file.ext ?? {}).containsKey('thumbnail')) {
        if (widget.zoomLevel.type == ZoomLevelType.list) {
          iconSize = iconSize * 1.6;
        }
        return ThumbnailWidget(
          file: file,
          width: isWidth ? iconSize : null,
          height: !isWidth ? iconSize : null,
        );
      }
    }
    return iconPackService.buildIcon(
      name: widget._entity.name,
      isDirectory: isDirectory,
      iconSize: iconSize,
    );
  }

  DirectoryViewState get sortFilter => widget.viewState;

  List<Widget> buildMeta(
    BuildContext context,
    Color? textColor,
    bool fullSize,
  ) {
    if (isDirectory)
      return [
        if (fullSize && dir.size != null)
          Container(
            width: sortFilter.columnWidthFilesize,
            alignment: Alignment.centerRight,
            child: Text(
              filesize(dir.size),
              style: TextStyle(
                color: textColor,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        Container(
          padding: const EdgeInsets.only(right: 8),
          width: sortFilter.columnWidthModified,
          alignment: Alignment.centerRight,
          child: StreamBuilder(
              stream: Stream.periodic(Duration(minutes: 1)),
              builder: (context, snapshot) {
                final dt = DateTime.fromMillisecondsSinceEpoch(dir.created);

                final timeAgoWidget = Text(
                  timeago.format(
                    dt,
                  ),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: textColor,
                  ),
                );

                var hovering = false;
                return StatefulBuilder(
                  builder: (context, setState) {
                    return MouseRegion(
                      onEnter: (event) {
                        setState(() {
                          hovering = true;
                        });
                      },
                      onExit: (event) {
                        setState(() {
                          hovering = false;
                        });
                      },
                      child: hovering
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatDateTime(dt),
                                  style: TextStyle(
                                    color: textColor,
                                  ),
                                  textAlign: TextAlign.end,
                                ),
                                timeAgoWidget,
                              ],
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.5,
                              ),
                              child: timeAgoWidget,
                            ),
                    );
                  },
                );
              }),
        ),
      ];
    final modifiedWidget = StreamBuilder(
        stream: Stream.periodic(Duration(minutes: 1)),
        builder: (context, snapshot) {
          final dt = DateTime.fromMillisecondsSinceEpoch(file.modified);

          final timeAgoWidget = Text(
            timeago.format(
              dt,
            ),
            textAlign: TextAlign.end,
            style: TextStyle(
              color: textColor,
            ),
          );

          if (!fullSize) {
            return timeAgoWidget;
          }

          var hovering = false;
          return StatefulBuilder(builder: (context, setState) {
            return MouseRegion(
              onEnter: (event) {
                setState(() {
                  hovering = true;
                });
              },
              onExit: (event) {
                setState(() {
                  hovering = false;
                });
              },
              child: hovering
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatDateTime(dt),
                          style: TextStyle(
                            color: textColor,
                          ),
                          textAlign: TextAlign.end,
                        ),
                        timeAgoWidget,
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.5,
                      ),
                      child: timeAgoWidget,
                    ),
            );
          });
          /*    final timeAgoWidget = Text(
            // ((fullSize && file.version > 0) ? 'modified ' : '') +
            timeago.format(
              DateTime.fromMillisecondsSinceEpoch(file.modified),
            ),
            textAlign: TextAlign.end,
            style: TextStyle(
              color: textColor,
            ),
          ); */

          /*  if (fullSize) {
            final modified = DateTime.fromMillisecondsSinceEpoch(file.modified);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat.yMEd().format(modified) +
                      ', ' +
                      DateFormat.Hm().format(modified),
                  style: TextStyle(
                    color: textColor,
                  ),
                  textAlign: TextAlign.end,
                ),
                timeAgoWidget,
              ],
            );
          } */
          // return timeAgoWidget;
        });

    final filesizeWidget = /* StateNotifierBuilder<FileState>(
        stateNotifier: storageService.dac.getFileStateChangeNotifier(
          file.file.hash,
        ),
        builder: (context, state, _) {
          return */
        Text(
      filesize(file.file.size),
      style: TextStyle(
        color: textColor,
      ),
      textAlign: TextAlign.end,
      /* ); */
      /* } */
    );

    final isAvailableOfflineWidget = StateNotifierBuilder<FileState>(
        stateNotifier: storageService.dac.getFileStateChangeNotifier(
          file.file.hash,
        ),
        builder: (context, state, _) {
          if (localFiles.containsKey(file.file.hash))
            return Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: Icon(
                UniconsLine.check_circle,
                size: 16,
                color: context.theme.colorScheme.secondary,
              ),
            );

          return SizedBox();
        });
    if (fullSize) {
      return [
        /*    if ((file.ext ?? {}).isNotEmpty)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
               [
                  // if (file.ext!.containsKey('thumbnail')) 'Has thumbnail',
                ].join('\n'),
                textAlign: TextAlign.start,
              ),
            ),
          ), */
        if (file.version > 0)
          Container(
            width: sortFilter.columnWidthVersion,
            alignment: Alignment.centerRight,
            child: Text('v${file.version}'),
          ),
        Container(
          width: sortFilter.columnWidthAvailableOffline,
          alignment: Alignment.centerRight,
          child: isAvailableOfflineWidget,
        ),
        Container(
          width: sortFilter.columnWidthFilesize,
          alignment: Alignment.centerRight,
          child: filesizeWidget,
        ),
        Container(
          width: sortFilter.columnWidthModified,
          alignment: Alignment.centerRight,
          child: modifiedWidget,
        ),
        SizedBox(
          width: 8,
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(right: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                isAvailableOfflineWidget,
                filesizeWidget,
              ],
            ),
            modifiedWidget,
          ],
        ),
      ),
      /*     Flexible(
        child: Text(
          file.file.toJson().toString(),
        ),
      ), */
    ];
  }

  List<TextSpan> renderImageMetadata(Map? map, BuildContext context) {
    final spans = <TextSpan>[];

    final highlightTextStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).primaryColor,
    );

    if (map?['image']['width'] != null) {
      spans.add(
        TextSpan(
          text: 'Res: ',
        ),
      );
      spans.add(
        TextSpan(
          text: '${map?['image']['width']}',
          style: highlightTextStyle,
        ),
      );
      spans.add(
        TextSpan(
          text: 'x',
        ),
      );
      spans.add(
        TextSpan(
          text: '${map?['image']['height']}',
          style: highlightTextStyle,
        ),
      );
    }

    if (map?['exif']?['GPSLongitude'] != null) {
      spans.add(
        TextSpan(
          text: ', has ',
        ),
      );
      spans.add(
        TextSpan(
          text: 'GPS',
          style: highlightTextStyle,
        ),
      );
    }
    return spans;
  }

  List<TextSpan> renderAudioMetadata(Map map, BuildContext context) {
    final spans = <TextSpan>[];

    final highlightTextStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).primaryColor,
    );

    if (map['track'] != null) {
      spans.add(
        TextSpan(
          text: '${map['track']}. ',
        ),
      );
    }
    if (map['title'] != null) {
      spans.add(
        TextSpan(
          text: '${map['title']} ',
          style: highlightTextStyle,
        ),
      );
      if (map['artist'] != null) {
        spans.add(
          TextSpan(
            text: 'by ',
          ),
        );
        spans.add(
          TextSpan(
            text: '${map['artist']} ',
            style: highlightTextStyle,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: '\n',
        ),
      );
      if (map['album'] != null) {
        spans.add(
          TextSpan(
            text: 'from ',
          ),
        );
        spans.add(
          TextSpan(
            text: '${map['album']} ',
            style: highlightTextStyle,
          ),
        );
      }
    }

    if (map['date'] != null) {
      String date = map['date'];
      if (date.length == 8) {
        if (!date.contains('-')) {
          date = date.substring(0, 4) +
              '-' +
              date.substring(4, 6) +
              '-' +
              date.substring(6, 8);
        }
      }
      spans.add(
        TextSpan(
          text: '${date} ',
        ),
      );
    }

    if (map['duration'] != null) {
      spans.add(
        TextSpan(
          text: '[',
        ),
      );
      spans.add(
        TextSpan(
          text: '${renderDuration(map['duration'])}',
          style: highlightTextStyle,
        ),
      );
      spans.add(
        TextSpan(
          text: ']',
        ),
      );
    }
    return spans;
  }

  List<TextSpan> renderPublicationMetadata(Map map, BuildContext context) {
    final spans = <TextSpan>[];

    final highlightTextStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).primaryColor,
    );

/*     spans.add(
      TextSpan(
        text: map.keys.toList().toString(),
      ),
    ); */
    String getValue(dynamic m) {
      if (m is List) {
        return m.map((e) => getValue(e)).join(', ');
      }
      if (m is Map) {
        return getValue(m.values.first);
      }
      return m.toString();
    }

    /* if (map['track'] != null) {
      spans.add(
        TextSpan(
          text: '${map['track']}. ',
        ),
      );
    } */

    if (map['title'] != null) {
      spans.add(
        TextSpan(
          text: '${getValue(map['title'])} ',
          style: highlightTextStyle,
        ),
      );
      if (map['author'] != null) {
        spans.add(
          TextSpan(
            text: '\n',
          ),
        );
        spans.add(
          TextSpan(
            text: 'by ',
          ),
        );
        spans.add(
          TextSpan(
            text: '${getValue(map['author'])} ',
            style: highlightTextStyle,
          ),
        );
        if (map['published'] != null) {
          String date = map['published'];
          if (date.length == 8) {
            if (!date.contains('-')) {
              date = date.substring(0, 4) +
                  '-' +
                  date.substring(4, 6) +
                  '-' +
                  date.substring(6, 8);
            }
          }
          spans.add(
            TextSpan(
              text: '${DateTime.tryParse(map['published'])?.year ?? ''}',
            ),
          );
        }
      }
    }

    /*    if (map['publisher'] != null) {
        spans.add(
          TextSpan(
            text: '\n',
          ),
        );
        spans.add(
          TextSpan(
            text: 'published by ',
          ),
        );
        spans.add(
          TextSpan(
            text: '${getValue(map['publisher'])} ',
            style: highlightTextStyle,
          ),
        );
      }
    
    } */
    spans.add(
      TextSpan(
        text: '\n',
      ),
    );
    if (map['wordCount'] != null) {
      spans.add(
        TextSpan(
          text: map['wordCount'].toString(),
          style: highlightTextStyle,
        ),
      );

      spans.add(
        TextSpan(
          text: ' words',
        ),
      );
    } else if (map['pageCount'] != null) {
      spans.add(
        TextSpan(
          text: map['pageCount'].toString(),
          style: highlightTextStyle,
        ),
      );

      spans.add(
        TextSpan(
          text: ' pages',
        ),
      );
    }

    if (map['language'] != null) {
      spans.add(
        TextSpan(
          text: ' [',
        ),
      );

      spans.add(
        TextSpan(
          text: getValue(map['language']),
          style: highlightTextStyle,
        ),
      );

      spans.add(
        TextSpan(
          text: ']',
        ),
      );
    }

    return spans;
  }
}

class ThumbnailCoverWidget extends StatefulWidget {
  final DirectoryFile file;

  ThumbnailCoverWidget({
    Key? key,
    required this.file,
  }) : super(key: ValueKey(file.ext!['thumbnail']['key']));

  @override
  State<ThumbnailCoverWidget> createState() => _ThumbnailCoverWidgetState();
}

class _ThumbnailCoverWidgetState extends State<ThumbnailCoverWidget> {
  late final thumbnail;
  late final thumbnailKey;
  @override
  void initState() {
    thumbnail = widget.file.ext!['thumbnail'];
    thumbnailKey = thumbnail['key'];

    if (!globalThumbnailMemoryCache.containsKey(thumbnailKey)) {
      _fetchData();
    } else {
      showBlurHash = false;
    }
    super.initState();
  }

  bool showBlurHash = true;

  void _fetchData() async {
    try {
      await Future.delayed(thumbnailLoadDelay);
      if (!mounted) return;

      globalThumbnailMemoryCache[thumbnailKey] =
          (await storageService.dac.loadThumbnail(
        thumbnailKey ?? 'none',
      ))!;

      if (mounted) setState(() {});
/*       await Future.delayed(Duration(milliseconds: 200));
      if (mounted)
        setState(() {
          showBlurHash = false;
        }); */
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      return SizedBox(
        child: SizedBox(
          height: cons.maxWidth,
          child: globalThumbnailMemoryCache.containsKey(thumbnailKey)
              ? AspectRatio(
                  aspectRatio: (thumbnail['aspectRatio'] ?? 1) + 0.0,
                  child: Image.memory(
                    globalThumbnailMemoryCache[thumbnailKey]!,
                    fit: BoxFit.cover,
                  ),
                )
              : BlurHash(
                  hash: thumbnail['blurHash'] ?? '00FFaX',
                ), /* Stack(
            fit: StackFit.expand,
            children: [
              if (globalThumbnailMemoryCache.containsKey(thumbnailKey))
                AspectRatio(
                  aspectRatio: (thumbnail['aspectRatio'] ?? 1) + 0.0,
                  child: Image.memory(
                    globalThumbnailMemoryCache[thumbnailKey]!,
                    fit: BoxFit.cover,
                  ),
                ),
              if (showBlurHash)
                BlurHash(
                  hash: thumbnail['blurHash'] ?? '00FFaX',
                ),
            ],
          ), */

          /* ), */
        ),
      );
    });
  }
}

class ThumbnailWidget extends StatefulWidget {
  final double? width;
  final double? height;

  ThumbnailWidget({
    Key? key,
    required this.file,
    required this.width,
    required this.height,
  }) : super(key: ValueKey(file.ext!['thumbnail']['key']));

  final DirectoryFile file;

  @override
  State<ThumbnailWidget> createState() => _ThumbnailWidgetState();
}

class _ThumbnailWidgetState extends State<ThumbnailWidget> {
  late final thumbnail;
  late final thumbnailKey;
  @override
  void initState() {
    thumbnail = widget.file.ext!['thumbnail'];
    thumbnailKey = thumbnail['key'];

    if (!globalThumbnailMemoryCache.containsKey(thumbnailKey)) {
      _fetchData();
    }
    super.initState();
  }

  void _fetchData() async {
    try {
      await Future.delayed(thumbnailLoadDelay);
      if (!mounted) return;

      globalThumbnailMemoryCache[thumbnailKey] =
          (await storageService.dac.loadThumbnail(
        thumbnailKey ?? 'none',
      ))!;
      /*   print(
        'tempImageCache ${globalThumbnailMemoryCache.values.fold<int>(0, (previousValue, el) => previousValue + el.length)}',
      ); */
      if (mounted) setState(() {});
    } catch (e, st) {
      logger.warning(e);
      logger.verbose(st);
    }
  }

  // Uint8List? imageBytes;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AspectRatio(
        aspectRatio: (thumbnail['aspectRatio'] ?? 1) + 0.0,
        child: !globalThumbnailMemoryCache.containsKey(thumbnailKey)
            ? BlurHash(
                hash: thumbnail['blurHash'] ?? '00FFaX',
              )
            : Image.memory(
                globalThumbnailMemoryCache[thumbnailKey]!,
                key: ValueKey('thumbnail_' + thumbnailKey),
              ),
      ),
    );
  }
}

String renderDuration(double y) {
  final x = y.round();
  String secs = (x % 60).toString();
  if (secs.length == 1) secs = '0$secs';

  String mins = ((x % 3600) / 60).floor().toString();
  if (mins.length == 1) mins = '0$mins';

  String str = '$mins:$secs';

  if (x >= 3600) {
    str = '${(x / 3600).floor()}:$str';
  }

  return str;
}
