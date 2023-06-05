import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/services.dart';
import 'package:flutter_state_notifier/flutter_state_notifier.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:vup/actions/base.dart';
import 'package:vup/actions/upload_directory.dart';
import 'package:vup/actions/upload_files.dart';

import 'package:vup/app.dart';
import 'package:vup/main.dart';
import 'package:vup/model/sync_task.dart';
import 'package:vup/utils/special_titles.dart';
import 'package:vup/utils/strings.dart';
import 'package:vup/view/directory.dart';
import 'package:vup/view/metadata_assistant.dart';
import 'package:vup/view/share_dialog.dart';
import 'package:vup/widget/audio_player.dart';

class BrowseView extends StatefulWidget {
  const BrowseView({required this.pathNotifier, Key? key}) : super(key: key);

  final PathNotifierState pathNotifier;

  @override
  _BrowseViewState createState() => _BrowseViewState();
}

class NavigateUpIntent extends Intent {}

class SelectAllIntent extends Intent {}

class CreateDirectoryIntent extends Intent {}

class _BrowseViewState extends State<BrowseView> {
  List<String> get path => widget.pathNotifier.value;

  PathNotifierState get pathNotifier => widget.pathNotifier;

  late DirectoryViewState directoryViewState;

  final focusNode = FocusNode(debugLabel: 'BrowseView');

  SyncTask? get activeSyncTask {
    for (final st in syncTasks.values) {
      if (st.remotePath == pathNotifier.path.join('/')) {
        return st;
      }
    }
  }

  // StreamSubscription? sub;

  @override
  void initState() {
    directoryViewState = DirectoryViewState(widget.pathNotifier);
    /* sub = .listen((event) {
      onPathChange();
    }); */
    /*    widget.pathNotifier.stream.listen((event) {
      if (mounted) setState(() {});
    }); */

    super.initState();
  }

/*   void onPathChange() {
    setState(() {
      // logger.verbose('pathNotifier event');
    });
  } */

  @override
  void dispose() {
    // sub?.cancel();
    super.dispose();
  }

  void navigateUp() {
    if (columnViewActive) {
      for (final column in appLayoutState.currentTab) {
        column.state.navigateUp();
      }
    } else {
      pathNotifier.value =
          pathNotifier.value.sublist(0, pathNotifier.value.length - 1);
    }
  }

  final pathScrollCtrl = ScrollController();

  bool get canWriteToDirectory => pathNotifier.value.length >= 1;

  final iconSize = 22.0;

  @override
  Widget build(BuildContext context) {
    if (widget.pathNotifier.noPathSelected) {
      return SizedBox();
    }
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape): NavigateUpIntent(),
        // LogicalKeySet(LogicalKeyboardKey.backspace): NavigateUpIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyA):
            SelectAllIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN):
            CreateDirectoryIntent(),
      },
      child: Actions(
        // dispatcher: LoggingActionDispatcher(),
        actions: <Type, Action<Intent>>{
          NavigateUpIntent: CallbackAction(onInvoke: (Intent intent) {
            navigateUp();
          }),
          CreateDirectoryIntent: CallbackAction(onInvoke: (Intent intent) {
            logger.verbose('CreateDirectoryIntent');
          }),
        },
        child: FocusScope(
          debugLabel: 'Scope',
          autofocus: true,
          child: Focus(
            // autofocus: true,
            focusNode: focusNode,
            onKey: (node, event) {
              // logger.verbose(event);
              isShiftPressed = event.isShiftPressed;
              isControlPressed = event.isControlPressed;

              // logger.verbose(FocusManager.instance.primaryFocus);
              return KeyEventResult.ignored;
            },
            /*  onKeyEvent: (node, event) {
              logger.verbose(event);
              return KeyEventResult.ignored;
            }, */
            onFocusChange: (value) {
              // logger.verbose('onFocusChange $value');
            },
            child: Builder(builder: (context) {
              final FocusNode focusNode = Focus.of(context);
              final bool hasFocus = focusNode.hasFocus;
              return GestureDetector(
                onTap: () {
                  if (hasFocus) {
                    // focusNode.unfocus();
                  } else {
                    focusNode.requestFocus();
                  }
                },
                child: StreamBuilder<Null>(
                    stream: widget.pathNotifier.stream,
                    builder: (context, snapshot) {
                      final uri = storageService.dac
                          .parsePath(path.join('/'))
                          .toString();

                      final hasWriteAccess =
                          storageService.dac.checkAccess(uri.toString());

                      /*         final sharedDirsIndex = storageService.dac
                          .getDirectoryMetadataCached(
                              'vup.hns/.internal/shared-directories'); */

                      bool isDirectorySharedReadOnly = false;
                      String? directoryShareUri;

                      /*    if (sharedDirsIndex != null) {
                        for (final sharedUri
                            in sharedDirsIndex.directories.keys) {
                          if (uri == sharedUri ||
                              '$uri/'.startsWith(sharedUri)) {
                            isDirectorySharedReadOnly = true;
                            directoryShareUri = sharedUri;
                            break;
                          }
                        }
                      } */
                      final nonMountedUri = storageService.dac
                          .parsePath(
                            path.join('/'),
                            resolveMounted: false,
                          )
                          .toString();

                      bool isDirectorySharedReadWrite = false;

                      for (final mountUri in storageService.dac.mounts.keys) {
                        if (nonMountedUri == mountUri ||
                            nonMountedUri.startsWith('$mountUri/')) {
                          isDirectorySharedReadWrite = true;
                          directoryShareUri =
                              storageService.dac.mounts[mountUri]?['uri'];
                          break;
                        }
                      }

                      bool isDirectoryShared =
                          path.isNotEmpty && path.first.startsWith('skyfs://');

                      bool isDirectoryAddedToSharedWithMe = false;

                      if (isDirectoryShared) {
                        if (widget.pathNotifier.toCleanUri().host == 'remote') {
                          isDirectoryShared = false;
                        } else {
                          final di =
                              storageService.dac.getDirectoryMetadataCached(
                            'vup.hns/shared-with-me',
                          );
                          if (di?.directories.containsKey(path.first) ??
                              false) {
                            isDirectoryAddedToSharedWithMe = true;
                          }
                        }
                      }
                      final customRemote =
                          storageService.getCustomRemoteForPath(uri);

                      return DropTarget(
                        onDragDone: (detail) async {
                          logger.verbose(
                            'dropped local files in $globalIsHoveringDirectoryUri',
                          );

                          final files = <File>[];
                          final directories = <Directory>[];
                          logger.verbose(detail.urls);

                          if (Platform.isWindows) {
                            for (final url in detail.urls) {
                              final path = Uri.decodeFull(url.path)
                                  .split('/')
                                  .where((element) => element.isNotEmpty)
                                  .toList()
                                  .join('\\');
                              if (File(path).existsSync()) {
                                files.add(
                                  File(
                                    path,
                                  ),
                                );
                              } else {
                                directories.add(
                                  Directory(
                                    path,
                                  ),
                                );
                              }
                            }
                          } else {
                            for (final url in detail.urls) {
                              final path = Uri.decodeFull(url.path);
                              if (File(path).existsSync()) {
                                files.add(
                                  File(
                                    path,
                                  ),
                                );
                              } else {
                                directories.add(
                                  Directory(
                                    path,
                                  ),
                                );
                              }
                            }
                          }
                          /* logger.verbose('files $files');
                          logger.verbose('directories $directories');
                          return; */
                          final currentUri = globalIsHoveringDirectoryUri ??
                              pathNotifier.toCleanUri().toString();

                          /* logger.verbose(
                              'globalIsHoveringDirectoryUri: $globalIsHoveringDirectoryUri');
                          logger.verbose(
                              'pathNotifier: ${pathNotifier.toCleanUri().toString()}'); */
                          final currentPath = pathNotifier.value;
                          try {
                            await uploadMultipleFiles(
                              context,
                              currentUri,
                              files,
                            );
                            for (final dir in directories) {
                              final name = basename(dir.path);
                              final di = storageService.dac
                                  .getDirectoryMetadataCached(currentUri)!;
                              if (!di.directories.containsKey(name)) {
                                await storageService.dac.createDirectory(
                                  currentUri,
                                  name,
                                );
                              }

                              storageService.startSyncTask(
                                dir,
                                (currentPath + [name]).join('/'),
                                SyncMode.sendOnly,
                                syncKey: Uuid().v4(),
                              );
                            }
                          } catch (e, st) {
                            if (context.canPop()) context.pop();
                            showErrorDialog(context, e, st);
                          }
                        },
                        child: Column(
                          children: [
                            if (false)
                              Builder(
                                // stream: Stream.empty(),
                                builder: (context) {
                                  // TODO Re-add the offline check
                                  if (false) {
                                    return Container(
                                      width: double.infinity,
                                      color: SkyColors.warning,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Offline mode enabled - no Internet access',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            /*    ElevatedButton(
                                              onPressed: () {},
                                              child: Text(
                                                'Add this shared directory to your sidebar',
                                              ),
                                            ) */
                                          ],
                                        ),
                                      ),
                                    );
                                  } else {
                                    return SizedBox();
                                  }
                                },
                              ),
                            if (!context.isMobile ||
                                !widget.pathNotifier.isSearching)
                              LayoutBuilder(builder: (context, cons) {
                                final actions = <Widget>[
                                  PopupMenuButton(
                                    tooltip: 'Upload files or directory',
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 5,
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        'Upload',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                        ),
                                      ),
                                    ),
                                    itemBuilder: (context) => [
                                      for (final ai in generateActions(
                                        false,
                                        null,
                                        pathNotifier,
                                        context,
                                        true,
                                        widget.pathNotifier.hasWriteAccess(),
                                        storageService.dac
                                            .getDirectoryStateChangeNotifier(
                                              widget.pathNotifier.value
                                                  .join('/'),
                                            )
                                            .state,
                                      ))
                                        if (ai.action is UploadFilesVupAction ||
                                            ai.action
                                                is UploadDirectoryVupAction)
                                          PopupMenuItem(
                                            onTap: () async {
                                              try {
                                                await ai.action
                                                    .execute(context, ai);
                                              } catch (e, st) {
                                                showErrorDialog(context, e, st);
                                              }
                                            },
                                            child: Row(
                                              children: [
                                                Icon(ai.icon),
                                                SizedBox(
                                                  width: 8,
                                                ),
                                                Text(
                                                  ai.label,
                                                ),
                                              ],
                                            ),
                                          ),
                                    ],
                                  ),

                                  /* SizedBox(
                                    width: 8,
                                  ), */
                                  /* ElevatedButton(
                                    onPressed: () {
                                      // TODO Create: directory or file (text, markdown)
                                      // TODO seach more prominent, maybe fully right
                                    },
                                    child: Text('Create'),
                                  ), */
                                ];

                                for (final ai in generateActions(
                                  false,
                                  null,
                                  pathNotifier,
                                  context,
                                  true,
                                  widget.pathNotifier.hasWriteAccess(),
                                  storageService.dac
                                      .getDirectoryStateChangeNotifier(
                                        widget.pathNotifier.value.join('/'),
                                      )
                                      .state,
                                )) {
                                  if (!(ai.action is UploadFilesVupAction ||
                                      ai.action is UploadDirectoryVupAction))
                                    actions.add(Tooltip(
                                      message: ai.label,
                                      child: InkWell(
                                        onTap: () async {
                                          try {
                                            await ai.action
                                                .execute(context, ai);
                                          } catch (e, st) {
                                            showErrorDialog(context, e, st);
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Icon(
                                            ai.icon,
                                            size: iconSize,
                                          ),
                                        ),
                                      ),
                                    ));
                                }

                                final searchButton = Tooltip(
                                  message: 'Search',
                                  child: InkWell(
                                    onTap: () async {
                                      if (pathNotifier.isSearching) {
                                        pathNotifier.disableSearchMode();
                                      } else {
                                        pathNotifier.enableSearchMode();
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        UniconsLine.search,
                                        size: iconSize,
                                      ),
                                    ),
                                  ),
                                );

                                /* 
                                  if (storageService.dac.checkAccess(
                                      widget.pathNotifier.value.join('/'))) ...[
                                    Tooltip(
                                      message: 'Create new directory',
                                      child: InkWell(
                                        onTap: () =>
                                            _createNewDirectory(context),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Icon(
                                            UniconsLine.folder_plus,
                                            size: iconSize,
                                          ),
                                        ),
                                      ),
                                    ),
                                  
                                  ],
                               
                                

                                
                                ]; */
                                final wrap = cons.maxWidth < mobileBreakpoint;
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: pathNotifier.value.isEmpty
                                              ? null
                                              : () {
                                                  navigateUp();
                                                },
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Icon(
                                              Icons.arrow_upward,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: LayoutBuilder(
                                              builder: (context, layout) {
                                            final specialTitle =
                                                getSpecialTitle(
                                              pathNotifier.toUriString(),
                                            );
                                            if (specialTitle != null) {
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Text(
                                                  specialTitle,
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                  ),
                                                ),
                                              );
                                            }
                                            return SingleChildScrollView(
                                              physics: BouncingScrollPhysics(),
                                              reverse: true,
                                              controller: pathScrollCtrl,
                                              scrollDirection: Axis.horizontal,
                                              child: ConstrainedBox(
                                                constraints: BoxConstraints(
                                                    minWidth: layout.maxWidth),
                                                child: Row(
                                                  children: [
                                                    for (int i = 0;
                                                        i <
                                                            pathNotifier
                                                                .value.length;
                                                        i++) ...[
                                                      if (i > 0)
                                                        Text(
                                                          '/',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 20,
                                                          ),
                                                        ),
                                                      InkWell(
                                                        borderRadius:
                                                            borderRadius,
                                                        onTap: columnViewActive
                                                            ? null
                                                            : () {
                                                                pathNotifier
                                                                        .value =
                                                                    pathNotifier
                                                                        .value
                                                                        .sublist(
                                                                            0,
                                                                            i + 1);
                                                              },
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(8.0),
                                                          child: Text(
                                                            pathNotifier
                                                                    .value[i]
                                                                    .startsWith(
                                                              'skyfs://',
                                                            )
                                                                ? 'Shared directory'
                                                                : pathNotifier
                                                                    .value[i],
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 20,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            );
                                          }),
                                        ),
                                        if (!wrap &&
                                            !widget.pathNotifier.isSearching)
                                          ...actions,
                                        searchButton,
                                      ],
                                    ),
                                    if (wrap &&
                                        !widget.pathNotifier.isSearching)
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          ...actions,
                                        ],
                                      )
                                  ],
                                );
                              }),
                            if (widget.pathNotifier.isSearching) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: TextField(
                                        controller: pathNotifier.searchTextCtrl,
                                        decoration: InputDecoration(
                                          hintText: 'Search...',
                                          border: OutlineInputBorder(),
                                          contentPadding: const EdgeInsets.only(
                                            left: 12,
                                            right: 12,
                                          ),
                                        ),
                                        autofocus: true,
                                        // scrollPadding: const EdgeInsets.only(top: 16),
                                        onChanged: (str) {
                                          // TODO Color search (thumbhash) and full-text search for image captions
                                          pathNotifier.setQueryParameters({
                                            'q': str,
                                            // 'query_by': 'ext.audio,name',
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      pathNotifier.disableSearchMode();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        UniconsLine.times_circle,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 8,
                                  ),
                                  /*   _buildChip(
                                    context,
                                    isSelected: pathNotifier.searchMode ==
                                        SearchMode.fromHere,
                                    label: 'From here',
                                    onTap: () {
                                      pathNotifier
                                          .setSearchMode(SearchMode.fromHere);
                                    },
                                  ),
                                  SizedBox(
                                    width: 8,
                                  ),
                                  _buildChip(
                                    context,
                                    isSelected: pathNotifier.searchMode ==
                                        SearchMode.allFiles,
                                    label: 'Everywhere',
                                    onTap: () {
                                      pathNotifier.path = [];
                                      pathNotifier
                                          .setSearchMode(SearchMode.allFiles);
                                    },
                                  ),
                                  SizedBox(
                                    width: 12,
                                  ),
                                  SizedBox(
                                    width: 12,
                                  ), */
                                  _buildChip(
                                    context,
                                    isSelected: pathNotifier.searchType == '*',
                                    label: 'All',
                                    onTap: () {
                                      pathNotifier.setQueryParameters({
                                        'type': '*',
                                      });
                                    },
                                  ),
                                  SizedBox(
                                    width: 8,
                                  ),
                                  _buildChip(
                                    context,
                                    isSelected:
                                        pathNotifier.searchType == 'file',
                                    label: context.isMobile
                                        ? 'Files'
                                        : 'Files only',
                                    onTap: () {
                                      pathNotifier.setQueryParameters({
                                        'type': 'file',
                                      });
                                    },
                                  ),
                                  SizedBox(
                                    width: 8,
                                  ),
                                  _buildChip(
                                    context,
                                    isSelected:
                                        pathNotifier.searchType == 'directory',
                                    label: context.isMobile
                                        ? 'Dirs'
                                        : 'Directories only',
                                    onTap: () {
                                      pathNotifier.setQueryParameters({
                                        'type': 'directory',
                                      });
                                    },
                                  ),
                                  /* SizedBox(
                                    width: 8,
                                  ),
                                  _buildChip(context, false), */
                                ],
                              ),
                              SizedBox(
                                height: 8,
                              ),
                            ],
                            Divider(
                              height: 1,
                              thickness: 1,
                            ),
                            if (!widget.pathNotifier.isSearching) ...[
                              if (activeSyncTask != null)
                                Container(
                                  width: double.infinity,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'This SkyFS directory is synchronized with "${activeSyncTask!.localPath}"',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              StreamBuilder<Null>(
                                  stream: pathNotifier.stream,
                                  builder: (context, snapshot) {
                                    String? jellyfinCollectionType;
                                    bool isRootDir = false;
                                    final segments =
                                        pathNotifier.toCleanUri().pathSegments;
                                    final currentPath = segments.join('/');

                                    for (final collection in dataBox.get(
                                            'jellyfin_server_collections') ??
                                        []) {
                                      final uri = storageService.dac
                                          .parsePath(collection['uri']);
                                      final path = uri.pathSegments.join('/');

                                      if ('${currentPath}/'.startsWith(path)) {
                                        jellyfinCollectionType =
                                            collection['type'];
                                        isRootDir = pathNotifier
                                                .toCleanUri()
                                                .pathSegments
                                                .length ==
                                            uri.pathSegments.length;
                                        break;
                                      }
                                      // jellyfinCollectionType = 'tvshows';
                                    }

                                    if (jellyfinCollectionType == null)
                                      return SizedBox();

                                    final mediaType = {
                                      // 'music',
                                      'tvshows': 'Series',
                                      'movies': 'Movie',
                                      // 'books',
                                    }[jellyfinCollectionType];

                                    return Container(
                                      width: double.infinity,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'This is a Jellyfin media directory of type "$jellyfinCollectionType"',
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 8,
                                            ),
                                            if (!isRootDir && mediaType != null)
                                              ElevatedButton(
                                                onPressed: () async {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) =>
                                                        AlertDialog(
                                                      content: SizedBox(
                                                        width: dialogWidth,
                                                        height: dialogHeight,
                                                        child:
                                                            MetadataAssistant(
                                                          widget.pathNotifier
                                                              .toCleanUri()
                                                              .toString(),
                                                          path.last,
                                                          mediaType: mediaType,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                                style: ButtonStyle(
                                                  backgroundColor:
                                                      MaterialStateProperty.all(
                                                    Colors.black,
                                                  ),
                                                  foregroundColor:
                                                      MaterialStateProperty.all(
                                                    Colors.white,
                                                  ),
                                                ),
                                                child: Text(
                                                  'Run metadata assistant',
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                            ],
                            if (isDirectoryShared) ...[
                              Container(
                                width: double.infinity,
                                color: Theme.of(context).primaryColor,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'You are browsing a shared directory',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (!isDirectoryAddedToSharedWithMe)
                                        ElevatedButton(
                                          onPressed: () async {
                                            showLoadingDialog(
                                              context,
                                              'Adding to "Shared with me" directory...',
                                            );
                                            final uri = path.first;

                                            final index = await storageService
                                                .dac
                                                .getDirectoryMetadata(uri);

                                            // TODO Use Links

                                            throw 'Not implemented';

                                            /*     await storageService.dac
                                                .doOperationOnDirectory(
                                                    storageService.dac
                                                        .parsePath(
                                                      'vup.hns/shared-with-me',
                                                    ), (di, writeKey) async {
                                              di.directories[uri] =
                                                  DirectoryDirectory(
                                                name:
                                                    renderFileSystemEntityCount(
                                                          index.files.length,
                                                          index.directories
                                                              .length,
                                                        ) +
                                                        ' (' +
                                                        [
                                                          ...index
                                                              .directories.keys,
                                                          ...index.files.keys
                                                        ].join(', ') +
                                                        ')',
                                                created: DateTime.now()
                                                    .millisecondsSinceEpoch,
                                              );
                                            }); */

                                            context.pop();

                                            pathNotifier.value = [
                                              'vup.hns',
                                              '.internal',
                                              'shared-with-me'
                                            ];
                                          },
                                          style: ButtonStyle(
                                            backgroundColor:
                                                MaterialStateProperty.all(
                                              Colors.black,
                                            ),
                                            foregroundColor:
                                                MaterialStateProperty.all(
                                              Colors.white,
                                            ),
                                          ),
                                          child: Text(
                                            'Add to your SkyFS',
                                          ),
                                        )
                                    ],
                                  ),
                                ),
                              )
                            ],
                            if (!hasWriteAccess)
                              Container(
                                width: double.infinity,
                                color: Theme.of(context).primaryColor,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'This directory is read-only',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            if (customRemote != null)
                              Container(
                                width: double.infinity,
                                color: Theme.of(context).primaryColor,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'New files uploaded to this directory are stored on the "$customRemote" remote',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            if (isDirectorySharedReadOnly)
                              Container(
                                width: double.infinity,
                                color: Theme.of(context).primaryColor,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'This directory is shared (read-only)',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          showShareResultDialog(
                                            context,
                                            'https://share.vup.app/#${await storageService.dac.getShareUriReadOnly(directoryShareUri!)}',
                                          );
                                        },
                                        style: ButtonStyle(
                                          backgroundColor:
                                              MaterialStateProperty.all(
                                            Colors.black,
                                          ),
                                          foregroundColor:
                                              MaterialStateProperty.all(
                                            Colors.white,
                                          ),
                                        ),
                                        child: Text(
                                          'Show share link',
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            if (isDirectorySharedReadWrite)
                              Container(
                                width: double.infinity,
                                color: Theme.of(context).primaryColor,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'This directory is shared (read and write)',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          showShareResultDialog(
                                            context,
                                            'https://share.vup.app/#$directoryShareUri',
                                          );
                                        },
                                        style: ButtonStyle(
                                          backgroundColor:
                                              MaterialStateProperty.all(
                                            Colors.black,
                                          ),
                                          foregroundColor:
                                              MaterialStateProperty.all(
                                            Colors.white,
                                          ),
                                        ),
                                        child: Text(
                                          'Show share link',
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            StreamBuilder<Null>(
                                stream: directoryViewState.stream,
                                builder: (context, _) {
                                  return LayoutBuilder(
                                      builder: (context, cons) {
                                    return Row(
                                      // TODO Including simplified mobile view (only sort)
                                      // TODO Also show simplified view in non-list mode
                                      children: [
                                        /*  Expanded(
                                            child: SizedBox(
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text('Name'),
                                              ),
                                            ),
                                          ), */
                                        /*        SizedBox(
                                            width: sortFilter.columnWidthFilesize,
                                            child: InkWell(
                                              onTap: () {
                                                sortFilter.click(SizeSortStep());
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text(
                                                  'Size',
                                                  textAlign: TextAlign.start,
                                                ),
                                              ),
                                            ),
                                          ), */
                                        // TODO Store sort type and order in statenotifier here
                                        // TODO make width configurable (maybe), but store it in the notifier too!
                                        for (final step in [
                                          NameSortStep(),
                                          // VersionSortStep(),
                                          if (cons.maxWidth > 650) ...[
                                            AvailableOfflineSortStep(),
                                            SizeSortStep(),
                                          ],
                                          ModifiedSortStep(),
                                        ])
                                          _buildSortStepWidget(step),
                                      ],
                                    );
                                  });
                                }),
                            Divider(
                              height: 1,
                              thickness: 1,
                            ),
                            // TODO Implement pinch to zoom (Android)
                            Expanded(
                              child: DirectoryView(
                                key: ValueKey(pathNotifier.toUriString()),
                                pathNotifier: pathNotifier,
                                viewState: directoryViewState,
                              ),
                            ),
                            StateNotifierBuilder<Map<String, List<String>>>(
                                stateNotifier: globalErrorsState,
                                builder: (context, state, _) {
                                  if (state.isEmpty) {
                                    return SizedBox();
                                  }

                                  return SizedBox(
                                    width: double.infinity,
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 0.0),
                                      child: Container(
                                        color: SkyColors.error,
                                        padding: const EdgeInsets.only(
                                          left: 8,
                                          right: 76,
                                          top: 0,
                                          bottom: 4,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  globalErrorsState.clear();
                                                },
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    top: 8.0,
                                                    bottom: 4.0,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.close,
                                                        color: Colors.black,
                                                        size: 28,
                                                      ),
                                                      Text(
                                                        'Errors',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 20,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            for (var e in state.keys) ...[
                                              Text(
                                                '$e',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              for (var c in state[e]!.take(3))
                                                Text(
                                                  '$c',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              if (state[e]!.length > 3)
                                                Text(
                                                  '…${state[e]!.length - 3} more',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              SizedBox(
                                                height: 4,
                                              ),
                                            ]
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                            MediaPlayerWidget(),
                          ],
                        ),
                      );
                    }),
              );
            }),
          ),
        ),
      ),
    );
  }

  InkWell _buildChip(
    BuildContext context, {
    required bool isSelected,
    required String label,
    required GestureTapCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        8,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Theme.of(context).dividerColor.withOpacity(0.6),
          ),
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.4)
              : null,
          borderRadius: BorderRadius.circular(
            8,
          ),
        ),
        padding: const EdgeInsets.all(8.0),
        child: Text(label),
      ),
    );
  }

  Widget _buildSortStepWidget(SortStep step) {
    final width = directoryViewState.getWidthForSortStep(step);
    final child = InkWell(
      onTap: () {
        directoryViewState.click(step);
      },
      child: Padding(
        padding: const EdgeInsets.all(0.0),
        child: Row(
          mainAxisAlignment:
              width == null ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            if (directoryViewState.firstSortStep.runtimeType ==
                step.runtimeType)
              Icon(
                directoryViewState.ascending
                    ? UniconsLine.angle_down
                    : UniconsLine.angle_up,
                size: 24,
              ),
            Padding(
              padding: EdgeInsets.only(
                left: width == null ? 6 : 0,
                right: 4 + (step is ModifiedSortStep ? 8 : 0),
                top: 4,
                bottom: 4,
              ),
              child: Text(
                step.name,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (width == null) {
      return Expanded(child: child);
    }
    return SizedBox(
      width: width,
      child: child,
    );
  }

  /* Future<void> _openTerminal(BuildContext context) async {
    final process = await Process.start(
      'konsole',
      [],
    );

    return;
  } */
}
