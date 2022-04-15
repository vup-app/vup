import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:alfred/alfred.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:contextmenu/contextmenu.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:tray_manager/tray_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:vup/model/sync_task.dart';
import 'package:sodium_libs/sodium_libs.dart' hide Box;
import 'package:vup/service/notification/provider/flutter.dart';
import 'package:vup/theme.dart';
import 'package:vup/utils/device_info/flutter.dart';
import 'package:vup/utils/external_ip/flutter.dart';
import 'package:vup/utils/ffmpeg/flutter.dart';
import 'package:vup/utils/ffmpeg/io.dart';
import 'package:vup/utils/strings.dart';
import 'package:vup/view/tab.dart';
import 'package:vup/widget/app_bar_wrapper.dart';
import 'package:vup/widget/vup_logo.dart';
import 'package:vup/widget/window_buttons.dart';
import 'package:uni_links/uni_links.dart';

import 'package:multi_split_view/multi_split_view.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vup/app.dart';
import 'package:vup/service/storage.dart';
import 'package:vup/view/browse.dart';

import 'package:vup/view/login_or_register.dart';
import 'package:vup/view/sidebar.dart';
import 'package:xdg_directories/xdg_directories.dart';
import 'package:selectable_autolink_text/selectable_autolink_text.dart';

import 'package:http/http.dart' as http;

final appLayoutState = AppLayoutState();

Future<void> initApp() async {
  if (Platform.isAndroid) {
    final tempDir = await getTemporaryDirectory();

    vupConfigDir = join(
      (await getApplicationDocumentsDirectory()).path,
      'vup',
    );
    vupTempDir = join(tempDir.path, 'vup');

    vupDataDir = join(
      (await getApplicationDocumentsDirectory()).path,
      'vup',
      'data',
    );
  } else if (Platform.isIOS) {
    final tempDir = await getTemporaryDirectory();
    vupTempDir = join(tempDir.path, 'vup');

    Directory? configDir;
    try {
      configDir = await getLibraryDirectory();
    } catch (e) {}

    configDir ??= await getApplicationDocumentsDirectory();

    vupConfigDir = join(
      configDir.path,
      'vup',
    );

    final supportDir = await getApplicationSupportDirectory();
    vupDataDir = join(
      supportDir.path,
      'vup',
      'data',
    );
  } else if (Platform.isWindows) {
    final tempDir = await getTemporaryDirectory();
    vupTempDir = join(tempDir.path, 'vup');

    final supportDir = await getApplicationSupportDirectory();

    vupConfigDir = join(
      supportDir.path,
      'config',
    );

    vupDataDir = join(
      supportDir.path,
      'data',
    );
  } else if (Platform.isLinux) {
    vupConfigDir = join(
      configHome.path,
      'vup',
    );

    final tempDir = await getTemporaryDirectory();
    vupTempDir = join(tempDir.path, 'vup');

    vupDataDir = join(dataHome.path, 'vup');
  } else if (Platform.isMacOS) {
    final tempDir = await getTemporaryDirectory();
    vupTempDir = join(tempDir.path, 'vup');

    vupConfigDir = join(
      (await getLibraryDirectory()).path,
      'vup',
    );

    final supportDir = await getApplicationSupportDirectory();
    vupDataDir = join(
      supportDir.path,
      'vup',
      'data',
    );
  } else {
    throw 'Unsupported platform';
  }

  await logger.init(vupTempDir);

  vupConfigDir = join(
    vupConfigDir, 'default',
    // 'debug',
  );

  logger.info('vupConfigDir $vupConfigDir');
  logger.info('vupTempDir $vupTempDir');
  logger.info('vupDataDir $vupDataDir');

  if (UniversalPlatform.isLinux || UniversalPlatform.isWindows) {
    ffMpegProvider = IOFFmpegProvider();
  } else {
    ffMpegProvider = FlutterFFmpegProvider();
  }
  notificationProvider = FlutterNotificationProvider();
  externalIpAddressProvider = FlutterExternalIpAddressProvider();
  deviceInfoProvider = FlutterDeviceInfoProvider();

  Hive.init(join(vupConfigDir, 'hive'));

  Hive.registerAdapter(SyncTaskAdapter());
  Hive.registerAdapter(SyncModeAdapter());

  logger.verbose('Opening Hive boxes...');

  dataBox = await Hive.openBox('data');
  isAppWindowVisible = !isStartMinimizedEnabled;

  if ((Platform.isLinux || Platform.isWindows || Platform.isMacOS) &&
      !dataBox.containsKey('double_click_enabled')) {
    dataBox.put('double_click_enabled', true);
  }

  mySky.setup(dataBox.get('cookie') ?? '');

  syncTasks = await Hive.openBox('syncTasks');

  directoryViewStates = await Hive.openBox('directoryViewStates');

  syncTasksTimestamps = await Hive.openBox('syncTasksTimestamps');
  syncTasksLock = await Hive.openBox('syncTasksLock');

  localFiles = await Hive.openBox('localFiles');

  logger.verbose('Creating storage service...');

  storageService = StorageService(
    mySky,
    isRunningInFlutterMode: true,
    syncTasks: syncTasks,
    temporaryDirectory: vupTempDir,
    dataDirectory: vupDataDir,
    localFiles: localFiles,
  );

  logger.verbose('Init storage service...');

  await storageService.init(await SodiumInit.init());

  logger.verbose('init MySky...');

  await mySky.init();

  logger.verbose('Setting up cache service...');

  cacheService.init(tempDirPath: vupTempDir);

  if (!(Platform.isWindows || Platform.isMacOS)) {
    logger.verbose('Setting up local notifications...');
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('sync');

    final IOSInitializationSettings initializationSettingsIOS =
        IOSInitializationSettings(
            /* onDidReceiveLocalNotification: onDidReceiveLocalNotification */);

    final MacOSInitializationSettings initializationSettingsMacOS =
        MacOSInitializationSettings();

    final InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
            macOS: initializationSettingsMacOS,
            linux:
                LinuxInitializationSettings(defaultActionName: 'helloworld'));

    await flutterLocalNotificationsPlugin!.initialize(initializationSettings,
        onSelectNotification: (str) {
      logger.info('onSelectNotification $str');
      if (str == null) return;
      if (str.startsWith('sync:')) {
        final task = syncTasks.get(str.substring(5));
        if (task != null) {
          appLayoutState.navigateTo(task.remotePath.split('/'));
        }
      }
    });
  }
  logger.verbose('Done with initApp');
}

void main(List<String> args) async {
  // Platform.environment['GDK_SCALE'] = '2';

  WidgetsFlutterBinding.ensureInitialized();

  if (!(Platform.isIOS || Platform.isAndroid)) {
    try {
      final res = await http.post(
        Uri.parse('http://localhost:43912/launch'),
        body: json.encode(
          {
            'action': 'launch',
            'args': args,
          },
        ),
        headers: {
          'content-type': 'application/json',
        },
      );
      if (res.statusCode != 200) {
        throw 'Not running';
      }
      exit(0);
    } catch (_) {}
    final vupServer = Alfred();

    vupServer.post('/launch', (req, res) async {
      try {
        if (!isAppWindowVisible) {
          appWindow.show();
          isAppWindowVisible = true;
        }
        final data = await req.bodyAsJsonMap;
        // logger.info('launch ${data}');
        if (data['action'] == 'launch') {
          appLayoutState.navigateToShareUri(
            'skyfs://' + data['args'][0].substring(12),
          );
        }
      } catch (_) {}

      return '';
    });

    vupServer.get('/vup-share-link', (req, res) async {
      try {
        if (!isAppWindowVisible && (Platform.isLinux || Platform.isWindows)) {
          appWindow.show();
          isAppWindowVisible = true;
        }
        final queryParameters = req.requestedUri.queryParameters;

        appLayoutState.navigateToShareUri(
          queryParameters['uri']!,
        );
      } catch (_) {}
      res.headers.contentType = ContentType.html;

      return '<script>window.close();</script>The shared directory has been opened in your local Vup app. You can close this tab now.';
    });

    vupServer.listen(43912, InternetAddress.loopbackIPv4, false);
  }

  /*  if (Platform.isWindows || Platform.isLinux) {
    await Window.initialize();
    await Window.setEffect(
      effect: WindowEffect.acrylic,
      color: Color(0xCC222222),
    );
  } */

  if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
    await TrayManager.instance.setIcon(
      Platform.isWindows
          ? 'assets/icon/tray_icon.ico'
          : 'assets/icon/tray_icon.png',
    );
    List<MenuItem> items = [
      MenuItem(
        key: 'toggle_window_visibility',
        title: 'Show/Hide Window',
      ),
      MenuItem.separator,
      MenuItem(
        key: 'exit_app',
        title: 'Exit App',
      ),
    ];
    await TrayManager.instance.setContextMenu(items);
  }

  await initApp();

  logger.verbose('Setting up global error handler...');

  FlutterError.onError = (fed) {
    logger.error(fed.exception);
    logger.verbose(fed.stack);
  };

  logger.verbose('Entering new error zone...');

  runZonedGuarded(() async {
    logger.verbose('Setting up sync tasks and watchers...');
    storageService.setupSyncTasks();
    storageService.setupWatchers();

    logger.verbose(
        'Starting user services if enabled... (Web, WebDav and Jellyfin)');

    if (isWebServerEnabled) {
      webServerService.start(webServerPort, webServerBindIp);
    }

    if (isWebDavServerEnabled) {
      webDavServerService.start(
        webDavServerPort,
        webDavServerBindIp,
        webDavServerUsername,
        webDavServerPassword,
      );
    }

    if (isJellyfinServerEnabled) {
      try {
        jellyfinServerService.start(
          jellyfinServerPort,
          jellyfinServerBindIp,
          jellyfinServerUsername,
          jellyfinServerPassword,
        );
      } catch (e, st) {
        logger.error('$e $st');
      }
    }

    if (Platform.isAndroid) {
      startAndroidBackgroundService();
    }

    if (UniversalPlatform.isLinux ||
        /* UniversalPlatform.isMacOS || */
        UniversalPlatform.isWindows) {
      try {
        final res = await Process.run(
          ytDlPath,
          [
            '--version',
          ],
          stdoutEncoding: systemEncoding,
        );
        isYTDlIntegrationEnabled = res.exitCode == 0;
      } catch (_) {}
    }

    packageInfo = await PackageInfo.fromPlatform();

    // await iconPackService.initCustomIconPack('candy-icons');

    // TODO Add Sentry and Sentry Feedback (feedback_sentry plugin)
    runApp(
      /* BetterFeedback(
      feedbackBuilder: (p0, p1) {
        
      },
      child: */
      MyApp(),
      /*  ), */
    );

    // await Window.initialize();

    /*  await Window.setEffect(
      effect: WindowEffect.transparent,
      color: Color(0xCC222222),
    ); */

    if (Platform.isLinux || Platform.isWindows /* || Platform.isMacOS */) {
      doWhenWindowReady(() {
        appWindow.minSize = Size(300, 440);
        appWindow.size = Size(1080, 640);
        //appWindow.size = Size(1536, 960);
        appWindow.alignment = Alignment.center;
        appWindow.title = 'Vup Cloud Storage'; // TODO Localization

        if (isStartMinimizedEnabled) {
          appWindow.hide();
        } else {
          appWindow.show();
        }
      });
    }
  }, (e, st) {
    logger.error(e);
    logger.verbose(st);
  });

  logger.verbose('Done with main().');
}

class MyApp extends StatelessWidget {
  final routerDelegate = BeamerDelegate(
    initialPath: mySky.isLoggedIn.value == true ? '/browse' : '/auth',
    locationBuilder: SimpleLocationBuilder(
      routes: {
        '/auth': (context, state) => AuthPage(),
        '/browse': (context, state) =>
            HomePage(MediaQuery.of(context).size.width),
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AppTheme(
      themedWidgetBuilder: (
        context,
        theme,
        darkTheme,
        themeMode,
      ) {
        return MaterialApp.router(
          themeMode: themeMode,
          theme: theme,
          darkTheme: darkTheme,
          routeInformationParser: BeamerParser(),
          routerDelegate: routerDelegate,
          // title: 'Vup',
          onGenerateTitle: (BuildContext context) =>
              AppLocalizations.of(context)!.title,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: (locales, supportedLocales) {
            for (final l in locales ?? []) {
              if (supportedLocales.contains(l)) {
                return l;
              }
            }
            return Locale('en');
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  final double initialWidth;

  HomePage(this.initialWidth);
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TrayListener {
  late MultiSplitViewController splitCtrl;

  void handleSharedLink(String? link) {
    logger.info('handleSharedLink $link');
    if (link == null) return;

    if (link.startsWith('vup://')) {
      appLayoutState.navigateToShareUri(
        'skyfs://' + link.substring(12),
      );
    } else {
      final uri = Uri.parse(link);
      appLayoutState.navigateToShareUri(
        uri.fragment,
      );
    }
  }

/*   late final FocusNode focus;
  FocusAttachment? _nodeAttachment; */

  @override
  void onTrayIconMouseDown() {
    TrayManager.instance.popUpContextMenu();
    logger.verbose('onTrayIconMouseDown');
  }

  @override
  void onTrayIconRightMouseDown() {
    TrayManager.instance.popUpContextMenu();
    logger.verbose('onTrayIconRightMouseDown');
  }

  @override
  void onTrayIconRightMouseUp() {
    logger.verbose('onTrayIconRightMouseUp');
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    logger.verbose('onTrayMenuItemClick ${menuItem.key}');
    if (menuItem.key == 'toggle_window_visibility') {
      if (isAppWindowVisible) {
        appWindow.hide();
      } else {
        appWindow.show();
      }
      isAppWindowVisible = !isAppWindowVisible;
    } else if (menuItem.key == 'exit_app') {
      exit(0);
    }
  }

  @override
  void initState() {
    initSplitCtrl();

    quotaService.update();

    Stream.periodic(Duration(minutes: 1)).listen((event) {
      quotaService.update();
    });

    if (Platform.isAndroid || Platform.isIOS) {
      getInitialLink().then(handleSharedLink);
      linkStream.listen((event) {
        handleSharedLink(event);
      });
    }

    TrayManager.instance.addListener(this);

    super.initState();
  }

  @override
  void dispose() {
    TrayManager.instance.removeListener(this);

    super.dispose();
  }

  void initSplitCtrl() {
    final sidebarWeight = max(0.16, min(250 / (widget.initialWidth), 0.5));

    final rest = 1 - sidebarWeight;

    splitCtrl = MultiSplitViewController(
      weights: [
        sidebarWeight,
        rest,
      ],
    );
  }

  late BuildContext buildContext;

  bool showedShareDialog = false;

  // bool searchQuery = '';

  @override
  Widget build(BuildContext context) {
    al = AppLocalizations.of(context)!;
    buildContext = context;

    return WillPopScope(
      onWillPop: () {
        appLayoutState.currentTab.first.state.pop();

        return Future.value(false);
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (event.buttons == kPrimaryButton ||
              event.kind == PointerDeviceKind.stylus) {
            if (globalDragAndDropPossible) {
              globalDragAndDropPointerDown = true;
            }
          }
        },
        onPointerUp: (details) {
          globalDragAndDropPointerDown = false;

          if (globalDragAndDropActive) {
            final targetUriString =
                globalDragAndDropUri ?? globalDragAndDropDirectoryViewUri;
            if (targetUriString != null) {
              final targetUri = Uri.parse(targetUriString);

              final entityStr = renderFileSystemEntityCount(
                globalDragAndDropSourceFiles.length,
                globalDragAndDropSourceDirectories.length,
              );
              final fileUris = globalDragAndDropSourceFiles;
              final directoryUris = globalDragAndDropSourceDirectories;
              showContextMenu(
                details.position,
                context,
                (ctx) => [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 4.0,
                      left: 16.0,
                      right: 16.0,
                      bottom: 4.0,
                    ),
                    child: Text(
                      'Dropped $entityStr in ${targetUri.pathSegments.isEmpty ? '' : targetUri.pathSegments.sublist(1).join('/')}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(UniconsLine.file_export),
                    title: Text(
                      'Move here',
                    ),
                    onTap: () async {
                      logger.info(
                          'moving ${fileUris} and ${directoryUris} to $targetUriString');
                      ctx.pop();
                      try {
                        showLoadingDialog(context, 'Moving $entityStr...');
                        final futures = <Future>[];

                        for (final uri in fileUris) {
                          futures.add(
                            storageService.dac.moveFile(
                              uri,
                              storageService.dac
                                  .getChildUri(targetUri,
                                      Uri.parse(uri).pathSegments.last)
                                  .toString(),
                            ),
                          );
                        }
                        for (final uri in directoryUris) {
                          futures.add(
                            storageService.dac.moveDirectory(
                              uri,
                              storageService.dac
                                  .getChildUri(targetUri,
                                      Uri.parse(uri).pathSegments.last)
                                  .toString(),
                            ),
                          );
                        }
                        await Future.wait(futures);
                        context.pop();
                      } catch (e, st) {
                        context.pop();
                        showErrorDialog(context, e, st);
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(UniconsLine.copy),
                    title: Text(
                      'Copy here',
                    ),
                    onTap: () async {
                      logger.info(
                          'copying ${fileUris} and ${directoryUris} to $targetUriString');
                      ctx.pop();
                      try {
                        showLoadingDialog(context, 'Copying $entityStr...');
                        final futures = <Future>[];

                        for (final uri in fileUris) {
                          futures.add(
                            storageService.dac.copyFile(
                              uri,
                              targetUri.toString(),
                            ),
                          );
                        }
                        for (final uri in directoryUris) {
                          final name = Uri.parse(uri).pathSegments.last;
                          futures.add(
                            storageService.dac.createDirectory(
                              targetUri.toString(),
                              name,
                            ),
                          );
                          futures.add(
                            storageService.dac.cloneDirectory(
                              uri,
                              storageService.dac
                                  .getChildUri(
                                    targetUri,
                                    name,
                                  )
                                  .toString(),
                            ),
                          );
                        }
                        await Future.wait(futures);
                        context.pop();
                      } catch (e, st) {
                        context.pop();
                        showErrorDialog(context, e, st);
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(UniconsLine.times),
                    title: Text(
                      'Cancel',
                    ),
                    onTap: () {
                      ctx.pop();
                    },
                  ),
                ],
                8.0,
                320.0,
              );
            }
          }
          globalDragAndDropActive = false;
        },
        child: Scaffold(
          drawer: context.isMobile
              ? Drawer(
                  child: SafeArea(
                    child: SidebarView(
                      appLayoutState: appLayoutState,
                    ),
                  ),
                )
              : null,
          appBar: !context.isMobile
              ? null
              : AppBarWrapper(
                  child: AppBar(
                    /*     leading: IconButton(
                        onPressed: () {
                          context.beamBack();
                        },
                        icon: Icon(
                          Icons.arrow_upward,
                        ),
                      ), */
                    title: VupLogo(),
                    /* 
                            :  */
                    actions: [
                      // TODO Notifications
                      /*  IconButton(
                            onPressed: () {
                              if (!_isSearching) {}
                              setState(() {
                                _isSearching = !_isSearching;
                              });
                            },
                            icon: Icon(
                              _isSearching ? Icons.close : Icons.search,
                            ),
                          ), */
                      /*  IconButton(
                        onPressed: () {},
                        icon: Icon(
                          UniconsLine.bell,
                        ),
                      ), */
                    ],
                  ),
                ),
          body: context.isMobile
              ? BrowseView(pathNotifier: appLayoutState.currentTab[0].state)
              : SafeArea(
                  child: MultiSplitViewTheme(
                    data: MultiSplitViewThemeData(
                      dividerThickness: 6,
                      dividerPainter: DividerPainters.background(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    child: MultiSplitView(
                      controller: splitCtrl,
                      minimalSize: 200,
                      children: [
                        SidebarView(appLayoutState: appLayoutState),
                        // for (final view in appLayoutState.views)
                        Column(
                          children: [
                            SizedBox(
                              height: (Platform.isWindows || Platform.isLinux)
                                  ? appWindow.titleBarHeight
                                  : 32,
                              child: Container(
                                color: Theme.of(context).dividerColor,
                                margin: const EdgeInsets.only(left: 1),
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: MoveWindow(
                                      child: StreamBuilder<Null>(
                                          stream: appLayoutState.stream,
                                          builder: (context, snapshot) {
                                            return /* Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 6.0,
                                                ),
                                                child: */
                                                Row(
                                              children: [
                                                for (int i = 0;
                                                    i <
                                                        appLayoutState
                                                            .tabs.length;
                                                    i++)
                                                  _buildTabIndicator(
                                                      i, context),
                                                InkWell(
                                                  onTap: () {
                                                    appLayoutState.createTab();
                                                  },
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            4.0),
                                                    child: Icon(
                                                      UniconsLine.plus,
                                                      size: 22,
                                                    ),
                                                  ),
                                                )
                                              ],
                                              /* ), */
                                            );
                                          }),
                                    )),
                                    WindowButtons(),
                                  ],
                                ),
                              ),
                            ),
                            /*    Container(
                                height: 6,
                                color: Theme.of(context).dividerColor,
                              ), */
                            Expanded(
                              child: StreamBuilder<Null>(
                                  stream: appLayoutState.stream,
                                  builder: (context, snapshot) {
                                    return TabView(
                                      tabIndex: appLayoutState.tabIndex,
                                    );
                                  }),
                            ),
                          ],
                        ),
                      ],
                    ),
                    /*   );
                          }), */
                  ),
                ),
        ),
      ),
      /*   ), */
    );
  }

  ClipRRect _buildTabIndicator(int i, BuildContext context) {
    final isSelected = i == appLayoutState.tabIndex;
    final borderRadius = BorderRadius.only(
/*       topLeft: i == 0 ? Radius.zero : Radius.circular(16),
      topRight: Radius.circular(16), */
        );
    return ClipRRect(
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () {
          appLayoutState.changeTab(i);
        },
        child: Container(
          color: isSelected
              ? Theme.of(context).backgroundColor
              : Colors.transparent,
          padding: const EdgeInsets.all(2),
          /* margin:
                                                      const EdgeInsets.all(4), */
          child: StreamBuilder<Null>(
              stream: appLayoutState.tabs[i][0].state.stream,
              builder: (context, snapshot) {
                return Row(
                  children: [
                    Settings.tabsTitleShowFullPath
                        ? SizedOverflowBox(
                            size: Size(164, 30),
                            alignment: Alignment.centerRight,
                            child: Text(
                                '${appLayoutState.tabs[i][0].state.path.join(' / ')}',
                                style: isSelected
                                    ? TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                      )
                                    : TextStyle()),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: SizedBox(
                              width: 156,
                              child: Text(
                                  '${appLayoutState.tabs[i][0].state.path.isEmpty ? '/' : appLayoutState.tabs[i][0].state.path.last}',
                                  maxLines: 1,
                                  style: isSelected
                                      ? TextStyle(
                                          color: Theme.of(context).primaryColor,
                                          fontWeight: FontWeight.bold,
                                        )
                                      : TextStyle()),
                            ),
                          ),
                    SizedBox(
                      width: 2,
                    ),
                    InkWell(
                      onTap: () {
                        appLayoutState.closeTab(i);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(
                          5.0,
                        ),
                        child: Icon(
                          UniconsLine.times,
                          size: 20,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : null,
                        ),
                      ),
                    )
                  ],
                );
              }),
        ),
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  @override
  void initState() {
    super.initState();
  }

  bool isFirstBuild = true;

  @override
  Widget build(BuildContext context) {
    al = AppLocalizations.of(context)!;
    if (isFirstBuild) {
      isFirstBuild = false;
      final disclaimerAccepted = dataBox.get('disclaimerAccepted') ?? false;
      if (!disclaimerAccepted) {
        Future.delayed(Duration(milliseconds: 200)).then((_) {
          showDialog(
            barrierDismissible: false,
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Things to know'),
              content: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vup is currently experimental. Always do external backups of your files.\n',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SelectableAutoLinkText(
                      [
                        'You can submit feedback or report bugs here: https://github.com/redsolver/vup/issues\n',
                        'Vup is open-source and licensed under the GPL-3.0 license.\nSource code: https://github.com/redsolver/vup\n',
                        if (!Platform.isIOS)
                          'You can support this project on GitHub Sponsors: https://github.com/sponsors/redsolver'
                      ].join(),
                      onTap: (url) {
                        launch(url);
                      },
                      linkStyle: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    dataBox.put('disclaimerAccepted', true);
                    context.pop();
                  },
                  child: Text('Accept'),
                ),
              ],
            ),
          );
        });
      }
    }
    if (context.isMobile) {
      return LoginOrRegisterPage();
    }
    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: (Platform.isWindows || Platform.isLinux)
                ? appWindow.titleBarHeight
                : 32,
            child: Container(
              color: Theme.of(context).dividerColor,
              child: Row(
                children: [
                  Expanded(child: MoveWindow(child: SizedBox())),
                  WindowButtons(),
                ],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 400,
                height: 660,
                child: LoginOrRegisterPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
