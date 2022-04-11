import 'dart:async';
import 'dart:io';

import 'package:contextmenu/contextmenu.dart';
import 'package:draggable_scrollbar/draggable_scrollbar.dart';

import 'package:vup/actions/base.dart';
import 'package:vup/app.dart';
import 'package:vup/utils/strings.dart';
import 'package:vup/view/browse.dart';
import 'package:vup/widget/file_system_entity.dart';
import 'package:vup/widget/flat_action_button.dart';

class DirectoryView extends StatefulWidget {
  final PathNotifierState pathNotifier;
  final DirectoryViewState viewState;

  DirectoryView({
    required this.pathNotifier,
    required this.viewState,
    Key? key,
  }) : super(key: key);

  @override
  _DirectoryViewState createState() => _DirectoryViewState();
}

class _DirectoryViewState extends State<DirectoryView> {
  DirectoryIndex? index;
  Map<String, DirectoryFile> uploadingFiles = {};

  ZoomLevel get zoomLevel => widget.viewState.zoomLevel;

  StreamSubscription? sub;
  StreamSubscription? sub2;
  StreamSubscription? sub3;

  @override
  void initState() {
    Future.delayed(Duration(milliseconds: 400)).then((value) {
      if ((index == null)) {
        if (mounted) {
          setState(() {
            showLoadingIndicator = true;
          });
        }
      }
    });
    _loadData();
    super.initState();
  }

  void _calculateSizes() async {
    if (isRecursiveDirectorySizesEnabled) {
      for (final dir in (index?.directories.keys.toList() ?? [])) {
        index!.directories[dir]!.size =
            await storageService.dac.calculateRecursiveDirectorySize(
          (widget.pathNotifier.path + [dir]).join('/'),
        );
      }
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    sub?.cancel();
    sub2?.cancel();
    sub3?.cancel();
    super.dispose();
  }

  void _loadData() async {
    final uri = widget.pathNotifier.toUriString();

    if (widget.pathNotifier.queryParamaters.isEmpty) {
      index = storageService.dac.getDirectoryIndexCached(
        uri,
      );
    }
    _calculateSizes();

    sub = storageService.dac
        .getDirectoryIndexChangeNotifier(
          storageService.dac.convertUriToHashForCache(
            storageService.dac.resolvePath(
              widget.pathNotifier.value.join('/'),
            ),
          ),
        )
        .stream
        .listen((_) {
      if (mounted) {
        setState(() {
          index = storageService.dac.getDirectoryIndexCached(
            uri,
          );
          sort();
        });
        _calculateSizes();
      }
    });

    final changeNotif = storageService.dac.getUploadingFilesChangeNotifier(
      widget.pathNotifier.toCleanUri().toString(),
    );
    uploadingFiles = changeNotif.state;

    sub2 = changeNotif.stream.listen((event) {
      if (mounted)
        setState(() {
          uploadingFiles = event;
          sort();
        });
    });

    if (index != null) {
      sort();
      if (mounted) setState(() {});
    }
    storageService.dac.getDirectoryIndex(uri).then((value) {
      if (mounted) {
        // TODO Detect offline errors instead
        if (value.files.isEmpty && value.directories.isEmpty) {
          if (index != null) {
            return;
          }
        }
        setState(() {
          index = value;
          sort();
        });
        _calculateSizes();
      }
    });

    sub3 = widget.viewState.stream.listen((event) {
      onSortFilterChange();
    });
  }

  void onSortFilterChange() {
    sort();
    setState(() {});
  }

  var entities = <dynamic>[];

  // TODO Use sort feature in FS DAC instead (with alpha-sort)
  void sort() {
    final files = index!.files.values.toList();
    files.sort((a, b) {
      for (final sortStep in widget.viewState.sortSteps) {
        final extractFunction = sortStep.f;

        final aVal = extractFunction(a);
        final bVal = extractFunction(b);

        if (aVal == null) {
          if (bVal == null) {
            return 0;
          } else {
            return 1;
          }
        } else if (bVal == null) {
          return -1;
        }
        int compareResult = aVal.compareTo(bVal);

        if (compareResult != 0) {
          if (!widget.viewState.ascending) {
            compareResult = -compareResult;
          }

          return compareResult;
        }
      }
      return 0;
    });

    final directories = index!.directories.values.toList();

    directories.sort((a, b) {
      return widget.viewState.sortDirectory(a, b);
    });

    entities = <dynamic>[
      ...directories,
      ...uploadingFiles.values,
      ...files,
    ];
  }

  bool showLoadingIndicator = false;

  @override
  Widget build(BuildContext context) {
    if (index == null) {
      return Align(
        child: AnimatedOpacity(
          duration: Duration(milliseconds: 400),
          opacity: showLoadingIndicator ? 1 : 0,
          child: LinearProgressIndicator(),
        ),
        alignment: Alignment.topCenter,
      );
    }

    final clipboardWidget = StreamBuilder(
      stream: globalClipboardState.stream,
      builder: (context, snapshot) {
        if (!globalClipboardState.isActive) return SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(
              height: 1,
              thickness: 1,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: LayoutBuilder(builder: (context, cons) {
                // final isFullSize = cons.maxWidth >= 600;
                final entityStr = renderFileSystemEntityCount(
                  globalClipboardState.fileUris.length,
                  globalClipboardState.directoryUris.length,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 6.0,
                            left: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(UniconsLine.layer_group),
                              SizedBox(
                                width: 8,
                              ),
                              Text(
                                (globalClipboardState.isCopy
                                        ? 'Copied '
                                        : 'Cut ') +
                                    entityStr,
                                style: TextStyle(
                                  fontSize: 16,
                                ),
                                /* ), */
                              ),
                            ],
                          ),
                        ),
                        globalClipboardState.isCopy
                            ? FlatActionButton(
                                icon: UniconsLine.copy,
                                label: 'Paste here',
                                onTap: () async {
                                  try {
                                    showLoadingDialog(
                                        context, 'Copying $entityStr...');
                                    final futures = <Future>[];

                                    for (final uri
                                        in globalClipboardState.fileUris) {
                                      futures.add(
                                        storageService.dac.copyFile(
                                          uri,
                                          widget.pathNotifier
                                              .toCleanUri()
                                              .toString(),
                                        ),
                                      );
                                    }
                                    for (final uri
                                        in globalClipboardState.directoryUris) {
                                      final name =
                                          Uri.parse(uri).pathSegments.last;
                                      futures.add(
                                        storageService.dac.createDirectory(
                                          widget.pathNotifier
                                              .toCleanUri()
                                              .toString(),
                                          name,
                                        ),
                                      );
                                      futures.add(
                                        storageService.dac.cloneDirectory(
                                          uri,
                                          storageService.dac
                                              .getChildUri(
                                                widget.pathNotifier
                                                    .toCleanUri(),
                                                name,
                                              )
                                              .toString(),
                                        ),
                                      );
                                    }
                                    await Future.wait(futures);
                                    context.pop();
                                    globalClipboardState.clearSelection();
                                  } catch (e, st) {
                                    context.pop();
                                    showErrorDialog(context, e, st);
                                  }
                                },
                              )
                            : FlatActionButton(
                                icon: UniconsLine.file_export,
                                label: 'Move here',
                                onTap: () async {
                                  try {
                                    showLoadingDialog(
                                        context, 'Moving $entityStr...');
                                    final futures = <Future>[];

                                    for (final uri
                                        in globalClipboardState.fileUris) {
                                      futures.add(
                                        storageService.dac.moveFile(
                                          uri,
                                          storageService.dac
                                              .getChildUri(
                                                  widget.pathNotifier
                                                      .toCleanUri(),
                                                  Uri.parse(uri)
                                                      .pathSegments
                                                      .last)
                                              .toString(),
                                        ),
                                      );
                                    }
                                    for (final uri
                                        in globalClipboardState.directoryUris) {
                                      futures.add(
                                        storageService.dac.moveDirectory(
                                          uri,
                                          storageService.dac
                                              .getChildUri(
                                                  widget.pathNotifier
                                                      .toCleanUri(),
                                                  Uri.parse(uri)
                                                      .pathSegments
                                                      .last)
                                              .toString(),
                                        ),
                                      );
                                    }
                                    await Future.wait(futures);
                                    context.pop();
                                    globalClipboardState.clearSelection();
                                  } catch (e, st) {
                                    context.pop();
                                    showErrorDialog(context, e, st);
                                  }
                                },
                              ),
                        FlatActionButton(
                          icon: UniconsLine.times,
                          label: 'Cancel',
                          onTap: () async {
                            globalClipboardState.clearSelection();
                          },
                        ),
                      ],
                    )
                  ],
                );
              }),
            ),
          ],
        );
      },
    );

    final stateNotifier = storageService.dac.getFileStateChangeNotifier(
      widget.pathNotifier.value.join('/'),
    );

    final directoryUri = widget.pathNotifier.toCleanUri().toString();

    final contextMenuBuilder = (ctx) {
      final actions = <Widget>[];
      for (final ai in generateActions(
        false,
        null,
        widget.pathNotifier,
        ctx,
        true,
        widget.pathNotifier.hasWriteAccess(),
        stateNotifier.state,
      )) {
        actions.add(ListTile(
          leading: ai.icon == null ? null : Icon(ai.icon),
          title: Text(ai.label),
          onTap: () async {
            context.pop();
            // return;
            try {
              await ai.action.execute(context, ai);
            } catch (e, st) {
              showErrorDialog(context, e, st);
            }
          },
        ));
      }
      return actions;
    };

    Widget gestureAreaBuilder(child) => MouseRegion(
          opaque: false,
          onEnter: (event) {
            globalDragAndDropDirectoryViewUri = directoryUri;
          },
          onExit: (event) {
            globalDragAndDropDirectoryViewUri = null;
          },
          child: GestureDetector(
            onSecondaryTapDown: (details) async {
              globalDragAndDropPossible = false;
              globalDragAndDropPointerDown = false;
              if (globalIsHoveringFileSystemEntity) return;

              showContextMenu(
                details.globalPosition,
                context,
                contextMenuBuilder,
                8.0,
                320.0,
              );
            },
            child: child,
          ),
        );

    // late Widget child;
    if ((index!.directories.length +
            index!.files.length +
            uploadingFiles.length) ==
        0) {
      return gestureAreaBuilder(
        Container(
          color: Colors.transparent,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: (widget.pathNotifier.path.join('/') == 'home' &&
                            !widget.pathNotifier.isSearching)
                        ? [
                            Text(
                              'Welcome to Vup!',
                              style: TextStyle(
                                fontSize: 24,
                              ),
                            ),
                            SizedBox(height: 16),
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 12, right: 12),
                              child: Text(
                                'It looks like your home directory is empty. Do you want to create some common sub-directories? (Documents, Music, ...)',
                                style: TextStyle(
                                  fontSize: 20,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () async {
                                showLoadingDialog(
                                  context,
                                  'Creating common directories...',
                                );
                                final dirs = [
                                  'Books',
                                  'Documents',
                                  'Music',
                                  'Videos',
                                  'Images',
                                ];

                                final futures = <Future>[];
                                for (final dir in dirs) {
                                  futures.add(
                                    storageService.dac.createDirectory(
                                      'home',
                                      dir,
                                    ),
                                  );
                                }
                                await Future.wait(futures);
                                context.pop();
                              },
                              child: Text('Create them!'),
                            ),
                          ]
                        : [
                            Text(
                              widget.pathNotifier.isSearching
                                  ? 'No search results found.'
                                  : 'This directory is empty.',
                              style: TextStyle(
                                fontSize: 24,
                              ),
                            ),
                          ],

                    /*  SizedBox(
                        height: 16,
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final result = await showTextInputDialog(
                            context: context,
                            textFields: [
                              DialogTextField(
                                hintText: 'skyfs://...',
                              ),
                            ],
                          );
                          if (result == null) {
                            return;
                          }
                          final sharedSeed = result[0].trim();
                          final uri = Uri.parse(sharedSeed);
                          print(sharedSeed);
                          await storageService.dac.mountUri(
                            widget.path.join('/'),
                            uri,
                          );
                          sub?.cancel();
                          sub2?.cancel();
                          _loadData();
                        },
                        child: Text(
                          'Mount shared directory here',
                        ),
                      ), */
                  ),
                ),
              ),
              clipboardWidget,
            ],
          ),
        ),
      );
    } else {
      // TODO Make this more efficient

      final int totalFileSize = index!.files.values.fold<int>(
        0,
        (previousValue, element) => previousValue + element.file.size,
      );
      final BoxScrollView contentView;
      if (zoomLevel.type == ZoomLevelType.list) {
        contentView = ListView.builder(
          controller: widget.viewState.scrollCtrl,
          itemCount: entities.length,
          itemBuilder: (context, index) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: FileSystemEntityWidget(
                    entities[index],
                    pathNotifier: widget.pathNotifier,
                    viewState: widget.viewState,
                  ),
                ),
              ],
            );
          },
        );
      } else {
        contentView = GridView.builder(
          controller: widget.viewState.scrollCtrl,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: zoomLevel.gridSize,
          ),
          itemCount: entities.length,
          itemBuilder: (context, index) {
            return SizedBox(
              // width: double.infinity,
              child: FileSystemEntityWidget(
                entities[index],
                pathNotifier: widget.pathNotifier,
                viewState: widget.viewState,
              ),
            );
          },
        );
      }

      final footerStr = renderFileSystemEntityCount(
        index!.files.length,
        index!.directories.length,
        totalFileSize,
      );

      return Actions(
        actions: <Type, Action<Intent>>{
          SelectAllIntent: CallbackAction(onInvoke: (Intent intent) {
            logger.verbose('SelectAllIntent');

            if ((widget.pathNotifier.selectedFiles.length +
                    widget.pathNotifier.selectedDirectories.length) !=
                (index!.files.length + index!.directories.length)) {
              widget.pathNotifier.selectedFiles.clear();
              widget.pathNotifier.selectedDirectories.clear();
              _selectAll();
            } else {
              widget.pathNotifier.selectedFiles.clear();
              widget.pathNotifier.selectedDirectories.clear();
            }

            widget.pathNotifier.$();
          }),
        },
        child: gestureAreaBuilder(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ((Platform.isAndroid || Platform.isIOS) &&
                        entities.length > 100)
                    ? DraggableScrollbar.semicircle(
                        controller: widget.viewState.scrollCtrl,
                        child: contentView,
                      )
                    : Scrollbar(
                        controller: widget.viewState.scrollCtrl,
                        child: contentView,
                      ),
              ),
              if (widget.pathNotifier.isInSelectionMode) ...[
                Divider(
                  height: 1,
                  thickness: 1,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: LayoutBuilder(builder: (context, cons) {
                    // final isFullSize = cons.maxWidth >= 600;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 6.0,
                                left: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(UniconsLine.layer_group),
                                  SizedBox(
                                    width: 8,
                                  ),
                                  /* Expanded(
                                          child:  */
                                  Text(
                                    'Selected ' +
                                        renderFileSystemEntityCount(
                                          widget.pathNotifier.selectedFiles
                                              .length,
                                          widget.pathNotifier
                                              .selectedDirectories.length,
                                        ),
                                    style: TextStyle(
                                      fontSize: 16,
                                    ),
                                    /* ), */
                                  ),
                                ],
                              ),
                            ),
                            FlatActionButton(
                                icon: UniconsLine.layer_group,
                                label: 'Select all',
                                onTap: () {
                                  widget.pathNotifier.selectedFiles.clear();
                                  widget.pathNotifier.selectedDirectories
                                      .clear();
                                  _selectAll();
                                  setState(() {});
                                } /* Actions.handler<SelectAllIntent>(
                                      context,
                                      SelectAllIntent(/* controller: controller */),
                                    )!, */
                                /* () {
                                      /* widget.pathNotifier.selectedDirectories.clear();
                                      widget.pathNotifier.selectedFiles.clear(); */
                                      widget.pathNotifier.$();
                                    }, */
                                ),
                            FlatActionButton(
                              icon: UniconsLine.layer_group_slash,
                              label: 'Unselect',
                              onTap: () {
                                widget.pathNotifier.clearSelection();
                              },
                            ),
                            FlatActionButton(
                              icon: UniconsLine.exchange,
                              label: 'Invert selection',
                              onTap: () {
                                final selFiles = List.from(
                                    widget.pathNotifier.selectedFiles);
                                final selDirs = List.from(
                                    widget.pathNotifier.selectedDirectories);
                                widget.pathNotifier.selectedFiles.clear();
                                widget.pathNotifier.selectedDirectories.clear();

                                _selectAll();

                                widget.pathNotifier.selectedFiles.removeWhere(
                                  (uri) => selFiles.contains(uri),
                                );
                                widget.pathNotifier.selectedDirectories
                                    .removeWhere(
                                  (uri) => selDirs.contains(uri),
                                );
                                setState(() {});
                                /* widget.pathNotifier.selectedDirectories.clear();
                                      widget.pathNotifier.selectedFiles.clear();
                                      widget.pathNotifier.$(); */
                              },
                            ),
                          ],
                        ),
                        Wrap(
                          children: [
                            for (final ai in generateActions(
                              true,
                              null,
                              widget.pathNotifier,
                              context,
                              false,
                              widget.pathNotifier.hasWriteAccess(),
                              stateNotifier.state,
                            ))
                              FlatActionButton(
                                icon: ai.icon ?? UniconsLine.question,
                                label: ai.label,
                                onTap: () async {
                                  try {
                                    await ai.action.execute(context, ai);
                                  } catch (e, st) {
                                    showErrorDialog(context, e, st);
                                  }
                                },
                              ),
                            /*    */
                            /*  FlatActionButton(
                                  icon: UniconsLine.copy,
                                  label: 'Copy all',
                                  onTap: () {
                                    globalClipboardState.directoryUris = Set.from(
                                        widget.pathNotifier.selectedDirectories);
                                    globalClipboardState.fileUris =
                                        Set.from(widget.pathNotifier.selectedFiles);
                                    globalClipboardState.isCopy = true;
                                    globalClipboardState.$();
                      
                                    widget.pathNotifier.clearSelection();
                                  },
                                ),
                                FlatActionButton(
                                  icon: UniconsLine.file_export,
                                  label: 'Move all',
                                  onTap: () {
                                    globalClipboardState.directoryUris = Set.from(
                                        widget.pathNotifier.selectedDirectories);
                                    globalClipboardState.fileUris =
                                        Set.from(widget.pathNotifier.selectedFiles);
                                    globalClipboardState.isCopy = false;
                                    globalClipboardState.$();
                      
                                    widget.pathNotifier.clearSelection();
                                  },
                                ), */
                          ],
                        )
                      ],
                    );
                  }),
                ),
              ],
              clipboardWidget,
              Divider(
                height: 1,
                thickness: 1,
              ),
              ContextMenuArea(
                builder: contextMenuBuilder,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: LayoutBuilder(builder: (context, cons) {
                    final isFullSize = cons.maxWidth >= 600;
                    final hasRoundedCorners =
                        MediaQuery.of(context).size.width < 600;
                    return Row(
                      children: [
                        if (hasRoundedCorners)
                          SizedBox(
                            width: 8,
                          ),
                        Expanded(
                          child: Text(
                            footerStr,
                            style: TextStyle(
                              fontSize: 15,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              zoomLevel.sizeValue = 0.2;
                              zoomLevel.type = ZoomLevelType.list;
                            });
                            widget.viewState.save();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              UniconsLine.list_ul,
                              color: zoomLevel.type == ZoomLevelType.list
                                  ? Theme.of(context).primaryColor
                                  : null,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              zoomLevel.sizeValue = 0.3;
                              zoomLevel.type = ZoomLevelType.grid;
                            });
                            widget.viewState.save();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              UniconsLine.table,
                              color: zoomLevel.type == ZoomLevelType.grid
                                  ? Theme.of(context).primaryColor
                                  : null,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              zoomLevel.sizeValue = 0.3;
                              zoomLevel.type = ZoomLevelType.gridCover;
                            });
                            widget.viewState.save();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              UniconsSolid.apps,
                              color: zoomLevel.type == ZoomLevelType.gridCover
                                  ? Theme.of(context).primaryColor
                                  : null,
                            ),
                          ),
                        ),
                        if (hasRoundedCorners)
                          SizedBox(
                            width: 16,
                          ),
                        if (isFullSize)
                          Slider(
                            value: zoomLevel.sizeValue,
                            onChanged: (value) {
                              setState(() {
                                zoomLevel.sizeValue = value;
                              });
                            },
                          )
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _selectAll() {
    for (final key in index!.files.keys) {
      /* if (key.startsWith('skyfs://')) {
        widget.pathNotifier.selectedFiles.add(key);
      } else { */
      widget.pathNotifier.selectedFiles.add(
        index!.files[key]!.uri!,
      );
    }
    for (final key in index!.directories.keys) {
      /* if (key.startsWith('skyfs://')) {
        widget.pathNotifier.selectedDirectories.add(key);
      } else { */

      widget.pathNotifier.selectedDirectories.add(
        index!.directories[key]!.uri!,
      );
      // }
    }
  }
}
