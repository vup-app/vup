import 'dart:async';
import 'dart:io';

import 'package:contextmenu/contextmenu.dart';
import 'package:filesize/filesize.dart';
import 'package:filesystem_dac/dac.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_state_notifier/flutter_state_notifier.dart';
import 'package:path/path.dart';
import 'package:vup/actions/base.dart';
import 'package:vup/app.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:open_file/open_file.dart';
import 'package:vup/main.dart';
import 'package:vup/utils/date_format.dart';

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
    final stateNotifier = storageService.dac.getFileStateChangeNotifier(
      isDirectory
          ? [...widget.pathNotifier.value, dir.name].join('/')
          : file.file.hash,
    );

    return ContextMenuArea(
      builder: (ctx) {
        final actions = <Widget>[];
        for (final ai in generateActions(
          !isDirectory,
          widget._entity,
          widget.pathNotifier,
          ctx,
          false,
          widget.pathNotifier.hasWriteAccess(),
          stateNotifier.state,
        )) {
          actions.add(ListTile(
            leading: ai.icon == null ? null : Icon(ai.icon),
            title: Text(ai.label),
            onTap: () async {
              ctx.pop();
              try {
                await ai.action.execute(context, ai);
              } catch (e, st) {
                showErrorDialog(context, e, st);
              }
            },
          ));
        }
        return actions;
      },
      /*  
         
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
                  
                    
                      showLoadingDialog(
                          context, 'Deleting file permanently...');
                      await storageService.dac.deleteFile(
                        uri,
                      );
          ],
        ],
   */
      child: InkWell(
        /*  onDoubleTap: () {
            print('onDoubleTap');
          }, */
        focusNode: focusNode,
        onHover: (value) {
          if (!isDoubleClickToOpenEnabled) return;
          globalIsHoveringFileSystemEntity = value;

          if (isDirectory) {
            globalIsHoveringDirectoryUri = value ? uri : null;
          }

          if (globalDragAndDropActive) {
            if (value && isDirectory) {
              globalDragAndDropUri = uri;
            } else {
              globalDragAndDropUri = null;
            }
            return;
          }

          if (value == true) {
            globalDragAndDropPossible = true;
            return;
          }
          if (globalDragAndDropPossible && globalDragAndDropPointerDown) {
            logger.verbose('start drag and drop operation');
            if (isSelected) {
              globalDragAndDropSourceFiles = widget.pathNotifier.selectedFiles;
              globalDragAndDropSourceDirectories =
                  widget.pathNotifier.selectedDirectories;
            } else {
              if (isDirectory) {
                globalDragAndDropSourceFiles = {};
                globalDragAndDropSourceDirectories = {uri};
              } else {
                globalDragAndDropSourceFiles = {uri};
                globalDragAndDropSourceDirectories = {};
              }
            }
            globalDragAndDropActive = true;
            globalDragAndDropUri = null;
            globalDragAndDropPossible = false;
            return;
          }
          globalDragAndDropPossible = false;
        },
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
                  if (stateNotifier.state.type != FileStateType.idle) return;
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

                    if (isIntegratedAudioPlayerEnabled &&
                        supportedAudioExtensionsForPlayback.contains(ext) &&
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

  Widget _buildContent(Color? textColor) {
    final stateNotifier = storageService.dac.getFileStateChangeNotifier(
      isDirectory
          ? [...widget.pathNotifier.value, dir.name].join('/')
          : file.file.hash,
    );

    if (widget.zoomLevel.type != ZoomLevelType.list) {
      final fileStateWidget = StateNotifierBuilder<FileState>(
          stateNotifier: stateNotifier,
          builder: (context, state, _) {
            return Row(
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
                if (!isDirectory && localFiles.containsKey(file.file.hash)) ...[
                  Icon(
                    UniconsLine.check_circle,
                    size: widget.zoomLevel.size * 0.23,
                    color: context.theme.colorScheme.secondary,
                  ),
                ]
              ],
            );
          });

      if (widget.zoomLevel.type == ZoomLevelType.gridCover && !isDirectory) {
        if ((file.ext ?? {}).containsKey('thumbnail'))
          return Stack(
            fit: StackFit.passthrough,
            children: [
              ThumbnailCoverWidget(
                file: file,
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.all(widget.zoomLevel.size * 0.1),
                  child: fileStateWidget,
                ),
              ),
            ],
          );
      }

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
          Padding(
            padding: EdgeInsets.only(
              right: widget.zoomLevel.size * 0.3,
              top: widget.zoomLevel.size * 0.2,
              left: widget.zoomLevel.size * 0.3,
            ),
            child: fileStateWidget,
          ),
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
