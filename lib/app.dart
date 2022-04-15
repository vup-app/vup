import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:filesystem_dac/dac.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:unicons/unicons.dart';
import 'package:vup/library/state.dart';
export 'package:build_context/build_context.dart';
export 'package:flutter/material.dart';
export 'package:unicons/unicons.dart';
export 'package:beamer/beamer.dart';
export 'package:vup/generic/state.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/service/base.dart';
import 'package:vup/service/icon_pack_service.dart';

export 'package:hive_flutter/hive_flutter.dart';

bool get devModeEnabled => dataBox.get('dev_mode_enabled') ?? false;

late PackageInfo packageInfo;

final thumbnailLoadDelay = Duration(milliseconds: 500);

bool get isRecursiveDirectorySizesEnabled =>
    dataBox.get('recursive_directory_sizes_enabled') ?? false;
bool get isDoubleClickToOpenEnabled =>
    dataBox.get('double_click_enabled') ?? false;

bool get isStartMinimizedEnabled =>
    dataBox.get('start_minimized_enabled') ?? false;

late bool isAppWindowVisible;

bool get isWatchOpenedFilesEnabled =>
    dataBox.get('watch_opened_files_enabled') ?? false;

bool get isIntegratedAudioPlayerEnabled =>
    dataBox.get('integrated_audio_player_enabled') ?? false;

bool get isColumnViewFeatureEnabled =>
    dataBox.get('column_view_enabled') ?? false;

class Settings {
  static bool get tabsTitleShowFullPath =>
      dataBox.get('tabs_title_show_full_path') ?? false;
}

late AppLocalizations al;

final globalThumbnailMemoryCache = <String, Uint8List>{};

bool isShiftPressed = false;
bool isControlPressed = false;

bool columnViewActive = false;

bool? isFFmpegInstalled;
bool? isUpdateAvailable;
bool isInstallationAvailable = false;

final iconPackService = IconPackService();

FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;

const AndroidNotificationDetails androidSyncNotificationChannelSpecifics =
    AndroidNotificationDetails(
  'sync',
  'Sync Status',
  channelDescription: 'Sends updates about the current sync status',
  importance: Importance.defaultImportance,
  priority: Priority.defaultPriority,
  ticker: 'ticker',
);
const NotificationDetails syncNotificationChannelSpecifics =
    NotificationDetails(
  android: androidSyncNotificationChannelSpecifics,
  linux: LinuxNotificationDetails(),
);

const dialogWidth = 600.0;
const dialogHeight = 700.0;

enum ZoomLevelType {
  list,
  grid,
  gridCover,
}

class ZoomLevel {
  ZoomLevelType type = ZoomLevelType.list;
  double get size {
    if (type == ZoomLevelType.list) {
      return sizeValue * 40 + 24;
    } else {
      return (sizeValue * 400 + 50) * 0.35;
    }
  }

  double get gridSize {
    return sizeValue * 400 + 50;
  }

  double sizeValue = 0.2;
}

final audioPlayer = AudioPlayer();

final borderRadius = BorderRadius.circular(8);

extension IsMobileExtension on BuildContext {
  bool get isMobile => MediaQuery.of(this).size.width < 600;
}

class SkyColors {
  static const error = Colors.deepOrange;
  static const warning = Color(0xffE19123);

  static const cardBackgroundColorOpacity = 0.1;
}

void showLoadingDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      content: ListTile(
        leading: CircularProgressIndicator(),
        title: Text(message),
      ),
    ),
    barrierDismissible: false,
  );
}

final iconMap = {
  FileStateType.downloading: UniconsLine.cloud_download,
  FileStateType.decrypting: UniconsLine.unlock_alt,
  FileStateType.encrypting: UniconsLine.lock_alt,
  FileStateType.uploading: UniconsLine.cloud_upload,
  FileStateType.sync: UniconsLine.sync_icon,
  FileStateType.idle: UniconsLine.clock,
};

enum SearchType {
  global,
  recursive,
  currentDir,
}

typedef dynamic ExtractFunction(DirectoryFile f);

abstract class SortStep {
  String get name;
  String get id;
  ExtractFunction get f;
}

/* class MediaSortStep extends SortStep {

  String type;
  String field;
  String name;

  ExtractFunction get f => (f) => f.ext?[type]?[field]?.toLowerCase();

  MediaSortStep({
    required this.name,
    required this.type,
    required this.field,
  });
} */

class NameSortStep extends SortStep {
  final id = 'name';
  final name = 'Name';
  final f = (f) => f.name.toLowerCase();
}

class CreatedSortStep extends SortStep {
  final id = 'created';
  final name = 'Created';
  final f = (f) => f.created;
}

class ModifiedSortStep extends SortStep {
  final id = 'modified';
  final name = 'Modified';
  final f = (f) => f.modified;
}

/* class VersionSortStep extends SortStep {
  final name = 'V';
  final f = (f) => f.version;
} */

class ExtensionSortStep extends SortStep {
  final id = 'extension';
  final name = 'Extension';
  final f = (f) => extension(f.name);
}

class SizeSortStep extends SortStep {
  final id = 'size';
  final name = 'Size';
  final f = (f) => f.file.size;
}

class AvailableOfflineSortStep extends SortStep {
  final id = 'availableOffline';
  final name = 'Offline';
  final f = (f) => localFiles.containsKey(f.file.hash).toString();
}

final allSortSteps = {
  'name': NameSortStep(),
  'created': CreatedSortStep(),
  'modified': ModifiedSortStep(),
  'extension': ExtensionSortStep(),
  'size': SizeSortStep(),
  'availableOffline': AvailableOfflineSortStep(),
};

late Box<Map> directoryViewStates;

class DirectoryViewState with CustomState, VupService {
  final PathNotifierState pathNotifier;

  final scrollCtrl = ScrollController();

  String? lastUri;

  DirectoryViewState(this.pathNotifier) {
    load();
    pathNotifier.stream.listen((event) {
      final uri = pathNotifier.toCleanUri().toString();
      if (lastUri == uri) return;
      load();
      lastUri = uri;
    });
  }

  void load() {
    verbose('load ${pathNotifier.toCleanUri()}');
    final key = sha1
        .convert(utf8.encode(pathNotifier.toCleanUri().toString()))
        .toString();
    final state = directoryViewStates.get(key) ??
        {
          'zoomLevelType': 'list',
          'ascending': true,
          'firstSortStep': 'name',
          'zoomLevelSizeValue': 0.2,
        };

    zoomLevel.type = ZoomLevelType.values.firstWhere(
      (element) =>
          element.toString() == 'ZoomLevelType.${state['zoomLevelType']}',
    ); // TODO make this more efficient

    zoomLevel.sizeValue = state['zoomLevelSizeValue'];

    ascending = state['ascending'];

    sortSteps = [
      allSortSteps[state['firstSortStep']]!,
    ];
  }

  void save() {
    final state = <String, dynamic>{
      'zoomLevelType': zoomLevel.type.toString().substring(14),
      'zoomLevelSizeValue': zoomLevel.sizeValue,
      'ascending': ascending,
      'firstSortStep': firstSortStep.id,
    };

    final key = sha1
        .convert(utf8.encode(pathNotifier.toCleanUri().toString()))
        .toString();

    directoryViewStates.put(key, state);

    verbose('save ${pathNotifier.toCleanUri()} $state');
  }

  final zoomLevel = ZoomLevel();

  SortStep get firstSortStep => sortSteps.first;

  List<SortStep> sortSteps = [
    /* MediaSortStep(name: 'Artist', type: 'audio', field: 'artist'),
    MediaSortStep(name: 'Album', type: 'audio', field: 'album'),
    MediaSortStep(name: 'Track', type: 'audio', field: 'track'), */
    NameSortStep(),
  ];

  final List<SortStep> sortBar = [];
  // ExtractFunction function = ;
  // SortType type = SortType.modified;

  bool ascending = true;

  double columnWidthVersion = 30;
  double columnWidthAvailableOffline = 80;
  double columnWidthFilesize = 100;
  double columnWidthModified = 180;

  void click(SortStep s) {
    if (firstSortStep.runtimeType == s.runtimeType) {
      ascending = !ascending;
    } else {
      sortSteps = [s];
      ascending = true;
    }
    $();
    save();
  }

  int sortDirectory(DirectoryDirectory a, DirectoryDirectory b) {
    if (firstSortStep is CreatedSortStep || firstSortStep is ModifiedSortStep) {
      final val = a.created.compareTo(b.created);
      if (!ascending) return -val;
      return val;
    } else if (firstSortStep is SizeSortStep) {
      final val = (a.size ?? 0).compareTo(b.size ?? 0);
      if (val != 0) {
        if (!ascending) return -val;
        return val;
      }
    }
    final val = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (!ascending) return -val;
    return val;
  }

  double? getWidthForSortStep(SortStep step) {
    return {
      // NameSortStep: columnWidth,
      // VersionSortStep: columnWidthVersion,
      AvailableOfflineSortStep: columnWidthAvailableOffline,
      SizeSortStep: columnWidthFilesize,
      ModifiedSortStep: columnWidthModified + 2,
    }[step.runtimeType];
  }
}

class AppLayoutState with CustomState {
  final tabs = [
    [
      AppLayoutViewState(PathNotifierState(['home'])),
    ],
  ];

  int tabIndex = 0;

  List<AppLayoutViewState> get currentTab => tabs[tabIndex];

  void changeTab(int tab) {
    tabIndex = tab;
    $();
  }

  void navigateTo(List<String> path) {
    tabs[tabIndex][0].state.value = path;

    // pathNotifier.value = str.substring(5).split('/');
  }

  void navigateToShareUri(String uri) {
    tabs[0][0].state.value = [uri];
  }

  void createTab({AppLayoutViewState? initialState}) {
    tabIndex = tabs.length;
    tabs.add([
      initialState ?? AppLayoutViewState(PathNotifierState(['home'])),
    ]);

    $();
  }

  void closeTab(int i) {
    if (tabs.length <= 1) return;
    tabs.removeAt(i);
    if (tabIndex >= i) {
      tabIndex--;
    }
    if (tabIndex < 0) {
      tabIndex = 0;
    }
    $();
  }
/* 
  void up() {
    views[0].state.value =
        views[0].state.value.sublist(0, views[0].state.value.length - 1);
  } */
}

class AppLayoutViewState {
  final PathNotifierState state;
  AppLayoutViewState(this.state);
}

Future<void> startAndroidBackgroundService({bool request = false}) async {
  if (!request) {
    if (!(await FlutterBackground.hasPermissions)) {
      return;
    }
  }

  final androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "Vup Service",
    notificationText: "Notification for keeping Vup running in the background",
    notificationImportance: AndroidNotificationImportance.Default,
    /*  notificationIcon: AndroidResource(
                  name: 'background_icon',
                  defType:
                      'drawable'),  */ // Default is ic_launcher from folder mipmap
  );
  // bool success =
  await FlutterBackground.initialize(androidConfig: androidConfig);
  // bool success2 =
  await FlutterBackground.enableBackgroundExecution();
}

Future<void> requestAndroidBackgroundPermissions() async {
  // await FlutterBackground.initialize();
  await startAndroidBackgroundService(request: true);
  if (!(await FlutterBackground.hasPermissions)) {
    throw 'Background Permission not granted';
  }
}

final globalClipboardState = GlobalClipboardState();

bool globalIsHoveringFileSystemEntity = false;
String? globalIsHoveringDirectoryUri;
bool globalDragAndDropPossible = false;
bool globalDragAndDropPointerDown = false;

Set<String> globalDragAndDropSourceFiles = {};
Set<String> globalDragAndDropSourceDirectories = {};

bool globalDragAndDropActive = false;
String? globalDragAndDropUri;
String? globalDragAndDropDirectoryViewUri;

class GlobalClipboardState with CustomState {
  bool isCopy = true;
  Set<String> fileUris = {};
  Set<String> directoryUris = {};
  bool get isActive => fileUris.isNotEmpty || directoryUris.isNotEmpty;

  void clearSelection() {
    fileUris.clear();
    directoryUris.clear();
    $();
  }
}

class PathNotifierState with CustomState {
  int columnIndex;

  bool noPathSelected = false;

  List<String> path = [];
  Set<String> selectedFiles = {};
  Set<String> selectedDirectories = {};

  bool get isInSelectionMode =>
      selectedFiles.isNotEmpty || selectedDirectories.isNotEmpty;

  int get selectionCount => selectedFiles.length + selectedDirectories.length;

  final searchTextCtrl = TextEditingController();

  PathNotifierState(this.path, {this.columnIndex = 0});

  bool isSearching = false;

  // bool get isAnythingSelected => null;

  void enableSearchMode() {
    isSearching = true;
    $();
  }

  void disableSearchMode() {
    globalIsHoveringFileSystemEntity = false;
    if (!isSearching) return;
    searchTextCtrl.clear();
    setQueryParameters({});
    isSearching = false;
    $();
  }

  List<String> get value => path;

  Map<String, String> queryParamaters = {};

  String toUriString() {
    return toUri().toString();
  }

  Uri toUri() {
    if (isSearching) {
      queryParamaters.addAll({'recursive': 'true'});
    }
    final uri = path.join('/');

    if (uri.startsWith('skyfs://')) {
      return Uri.parse(uri);
    }

    return Uri(
      host: 'local',
      scheme: 'skyfs',
      pathSegments: [DATA_DOMAIN] + path,
      queryParameters: queryParamaters.isEmpty ? null : queryParamaters,
    );
  }

  Uri toCleanUri() {
    final uri = path.join('/');

    if (uri.startsWith('skyfs://')) {
      return Uri.parse(uri);
    }

    return Uri(
      host: 'local',
      scheme: 'skyfs',
      pathSegments: [DATA_DOMAIN] + path,
      // queryParameters: queryParamaters.isEmpty ? null : queryParamaters,
    );
  }

/*   String getChildUri(String name) {
    return Uri(
      host: 'local',
      scheme: 'skyfs',
      pathSegments: [DATA_DOMAIN] + path + [name],
      queryParameters: queryParamaters.isEmpty ? null : queryParamaters,
    ).toString();
  } */

  void setQueryParameters(Map<String, String> params) {
    queryParamaters.addAll(params);
    $();
  }

  set value(List<String> value) {
    selectedDirectories.clear();
    selectedFiles.clear();

    disableSearchMode();
    path = value;
    queryParamaters = {};
    $();
  }

  String get searchType => queryParamaters['type'] ?? '*';

  SearchMode searchMode = SearchMode.fromHere;

  void setSearchMode(SearchMode mode) {
    searchMode = mode;
    $();
  }

  void pop() {
    value = value.sublist(0, value.length - 1);
  }

  void navigateUp() {
    if (path.isEmpty) return;
    value = path.sublist(0, path.length - 1);
  }

  void clearSelection() {
    if (!isInSelectionMode) return;
    selectedDirectories.clear();
    selectedFiles.clear();
    $();
  }

  bool get isInTrash => (path.length >= 2) && path[1] == '.trash';

  bool hasWriteAccess() {
    return storageService.dac.checkAccess(path.join('/')) && !isInTrash;
  }
}

enum SearchMode {
  fromHere,
  allFiles,
}

Future<void> uploadMultipleFiles(
  BuildContext context,
  String path,
  List<File> files,
) async {
  await Future.wait([
    for (final file in files) storageService.startFileUploadingTask(path, file),
  ]);
}

void showErrorDialog(BuildContext context, dynamic e, dynamic st,
    {Widget? widget, bool dismissable = true}) {
  logger.error('$e: $st');
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Error'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              UniconsLine.exclamation_triangle,
              color: SkyColors.error,
            ),
            title: Text(e.toString()),
          ),
          if (widget != null) widget,
        ],
      ),
      actions: [
        if (dismissable)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
            ),
          ),
      ],
    ),
    barrierDismissible: dismissable,
  );
}

final titleTextStyle = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.bold,
);
final subTitleTextStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.bold,
);

Future showInfoDialog(
  BuildContext context,
  String title,
  String content,
) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: content.isEmpty
          ? null
          : Text(
              content,
              style: Theme.of(context).textTheme.bodyText2,
            ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Ok'),
        )
      ],
    ),
  );
}
