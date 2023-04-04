import 'package:open_file/open_file.dart';
import 'package:uuid/uuid.dart';
import 'package:vup/app.dart';
import 'package:vup/page/settings/advanced.dart';
import 'package:vup/page/settings/cache.dart';
import 'package:vup/page/settings/custom_themes.dart';
import 'package:vup/page/settings/devices.dart';
import 'package:vup/page/settings/jellyfin.dart';
import 'package:vup/page/settings/mounts.dart';
import 'package:vup/page/settings/portal_auth.dart';
import 'package:vup/page/settings/remotes.dart';
import 'package:vup/page/settings/scripts.dart';
import 'package:vup/page/settings/ui_settings.dart';
import 'package:vup/page/settings/web_server.dart';
import 'package:vup/page/settings/webdav.dart';
import 'package:vup/view/share_dialog.dart';
import 'package:vup/widget/app_bar_wrapper.dart';
import 'package:vup/widget/theme_switch.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class SettingsPane {
  final String title;
  final Function build;

  SettingsPane({
    required this.title,
    required this.build,
  });
}

class _SettingsPageState extends State<SettingsPage> {
  final panes = [
    SettingsPane(
      title: 'Preferences',
      build: () => UISettingsPage(),
    ),
    SettingsPane(
      title: 'Portal Auth',
      build: () => PortalAuthSettingsPage(),
    ),
    SettingsPane(
      title: 'Devices',
      build: () => DevicesSettingsPage(),
    ),
    SettingsPane(
      title: 'Custom themes',
      build: () => CustomThemesSettingsPage(),
    ),
    SettingsPane(
      title: 'Web Server',
      build: () => WebServerSettingsPage(),
    ),
    /* SettingsPane(
      title: 'Jellyfin Server',
      build: () => JellyfinServerSettingsPage(),
    ), */
    SettingsPane(
      title: 'WebDAV Server',
      build: () => WebDavSettingsPage(),
    ),
    SettingsPane(
      title: 'Manage Cache',
      build: () => CacheSettingsPage(),
    ),
    if (devModeEnabled) ...[
      SettingsPane(
        title: 'Edit mounts.json',
        build: () => MountsSettingsPage(),
      ),
      SettingsPane(
        title: 'Edit remotes.json',
        build: () => RemotesSettingsPage(),
      ),
    ],
    SettingsPane(
      title: 'Advanced',
      build: () => AdvancedSettingsPage(),
    ),
    if (devModeEnabled && isYTDlIntegrationEnabled)
      SettingsPane(
        title: 'Scripts (Advanced)',
        build: () => ScriptsSettingsPage(),
      ),
    /* SettingsPane(
      title: 'Koel Music Server',
      build: () => KoelServerSettingsPage(),
    ), */
  ];
  Widget currentPaneChild = Center(
    child: Text('Select a settings category in the left sidebar'),
  );
  String currentPaneTitle = '';

  final _scrollCtrl = ScrollController();

  @override
  Widget build(BuildContext context) {
    final listView = ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.only(
        top: 16,
      ),
      children: [
        Column(
          children: [
            Text(
              'Theme',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(
              height: 6,
            ),
            ThemeSwitch(),
          ],
        ),
        Divider(),
        for (final pane in panes)
          ListTile(
            title: Text(pane.title),
            trailing: Icon(Icons.arrow_forward),
            selected: currentPaneTitle == pane.title,
            onTap: context.isMobile
                ? () {
                    context.push(
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBarWrapper(
                            child: AppBar(
                              title: Text(pane.title),
                            ),
                          ),
                          body: pane.build(),
                        ),
                      ),
                    );
                  }
                : () {
                    currentPaneChild = pane.build();
                    currentPaneTitle = pane.title;
                    setState(() {});
                  },
          ),
        ListTile(
          title: Text('About Vup'),
          leading: Icon(Icons.info),
          onTap: () {
            showAboutDialog(
              applicationLegalese:
                  'Copyright © 2022 redsolver. Licensed under the terms of the EUPL-1.2 license.',
              applicationName: 'Vup',
              applicationVersion: packageInfo.version,
              context: context,
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SelectableText('Log file: ${logger.logFilePath}'),
        ),
        Center(
          child: Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  OpenFile.open(logger.logFilePath);
                },
                child: Text(
                  'Open log file',
                ),
              ),
              SizedBox(
                height: 12,
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    showLoadingDialog(
                      context,
                      'Uploading log file and generating share link...',
                    );
                    final uuid = Uuid().v4();

                    await storageService.dac.createDirectory(
                      'vup.hns/shared-static-directories',
                      uuid,
                    );
                    final shareUri = storageService.dac
                        .parsePath('vup.hns/shared-static-directories/$uuid');

                    await storageService.startFileUploadingTask(
                      shareUri.toString(),
                      logger.logFile,
                    );

                    final shareSeed =
                        await storageService.dac.getShareUriReadOnly(
                      shareUri.toString(),
                    );

                    final shareLink = 'https://share.vup.app/#${shareSeed}';
                    context.pop();
                    showShareResultDialog(context, shareLink);
                  } catch (e, st) {
                    context.pop();
                    showErrorDialog(context, e, st);
                  }
                },
                child: Text(
                  'Generate share link for log file',
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 24,
        ),
      ],
    );
    return Scaffold(
      appBar: AppBarWrapper(
        child: AppBar(
          title: Text(
            'Settings',
          ),
        ),
      ),
      body: context.isMobile
          ? listView
          : Row(
              children: [
                SizedBox(
                  width: 400,
                  child: listView,
                ),
                Expanded(
                  child: currentPaneChild,
                )
              ],
            ),
    );
  }
}
