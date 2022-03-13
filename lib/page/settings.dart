import 'package:vup/app.dart';
import 'package:vup/page/settings/advanced.dart';
import 'package:vup/page/settings/cache.dart';
import 'package:vup/page/settings/custom_themes.dart';
import 'package:vup/page/settings/jellyfin.dart';
import 'package:vup/page/settings/portal_auth.dart';
import 'package:vup/page/settings/scripts.dart';
import 'package:vup/page/settings/ui_settings.dart';
import 'package:vup/page/settings/web_server.dart';
import 'package:vup/page/settings/webdav.dart';
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
      title: 'Portal Auth',
      build: () => PortalAuthSettingsPage(),
    ),
    /*  SettingsPane(
      title: 'Manage file system index',
      build: () => ManageFSIndexPage(),
    ), */
    SettingsPane(
      title: 'Behaviour',
      build: () => UISettingsPage(),
    ),
    SettingsPane(
      title: 'Custom themes',
      build: () => CustomThemesSettingsPage(),
    ),
    SettingsPane(
      title: 'Web Server',
      build: () => WebServerSettingsPage(),
    ),
    SettingsPane(
      title: 'Jellyfin Server',
      build: () => JellyfinServerSettingsPage(),
    ),
    SettingsPane(
      title: 'WebDav Server',
      build: () => WebDavSettingsPage(),
    ),
    SettingsPane(
      title: 'Manage Cache',
      build: () => CacheSettingsPage(),
    ),
    SettingsPane(
      title: 'Advanced',
      build: () => AdvancedSettingsPage(),
    ),
    if (devModeEnabled && isYTDlIntegrationEnabled)
      SettingsPane(
        title: 'Hooks/tasks/workflows/scripts (Advanced)',
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
                  'Copyright © 2022 redsolver. All rights reserved.',
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
