import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:path/path.dart';
import 'package:vup/app.dart';

class UISettingsPage extends StatefulWidget {
  const UISettingsPage({Key? key}) : super(key: key);

  @override
  _UISettingsPageState createState() => _UISettingsPageState();
}

class _UISettingsPageState extends State<UISettingsPage> {
  @override
  void initState() {
    if (Platform.isLinux) {
      final appDir = join(storageService.dataDirectory, 'app');
      final appImageGenericLink = Link(join(appDir, 'vup-latest.AppImage'));

      launchAtStartup.setup(
        appName: packageInfo.appName,
        appPath: appImageGenericLink.path,
      );
    } else {
      launchAtStartup.setup(
        appName: packageInfo.appName,
        appPath: Platform.resolvedExecutable,
      );
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(
          height: 16,
        ),
        CheckboxListTile(
          value: isRecursiveDirectorySizesEnabled,
          title: Text('Show directory sizes'),
          subtitle: Text(
            'When enabled, the total file size of all files in a directory, including all subdirectories, is calculated and shown. This can impact performance and is experimental.',
          ),
          onChanged: (val) {
            dataBox.put('recursive_directory_sizes_enabled', val!);

            setState(() {});
          },
        ),
        CheckboxListTile(
          value: isDoubleClickToOpenEnabled,
          title: Text('Double click'),
          subtitle: Text(
            'When enabled, you need to double-click to open files and directories.',
          ),
          onChanged: (val) {
            dataBox.put('double_click_enabled', val!);

            setState(() {});
          },
        ),
        CheckboxListTile(
          value: Settings.tabsTitleShowFullPath,
          title: Text('Show full path in tabs title'),
          onChanged: (val) {
            dataBox.put('tabs_title_show_full_path', val!);

            setState(() {});
          },
        ),
        CheckboxListTile(
          value: isColumnViewFeatureEnabled,
          title: Text('Enable Column View (Experimental)'),
          subtitle: Text(
            'When enabled, there will be a new button in the top left to enable a view with 4 linked columns.',
          ),
          onChanged: (val) {
            dataBox.put('column_view_enabled', val!);

            setState(() {});
          },
        ),
        CheckboxListTile(
          value: isWatchOpenedFilesEnabled,
          title: Text('Watch opened files'),
          subtitle: Text(
            'When enabled, opened files will be watched for changes and new versions uploaded automatically.',
          ),
          onChanged: (val) {
            dataBox.put('watch_opened_files_enabled', val!);

            setState(() {});
          },
        ),
        if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) ...[
          CheckboxListTile(
            value: isStartMinimizedEnabled,
            title: Text('Start minimized'),
            subtitle: Text(
              'When enabled, Vup is minimized to the system tray when launched.',
            ),
            onChanged: (val) {
              dataBox.put('start_minimized_enabled', val!);

              setState(() {});
            },
          ),
          FutureBuilder<bool>(
            future: launchAtStartup.isEnabled(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return SizedBox();
              return CheckboxListTile(
                value: snapshot.data,
                title: Text('Launch at startup'),
                subtitle: Text(
                  'When enabled, Vup will be automatically launched with your system.',
                ),
                onChanged: (val) async {
                  if (val == true) {
                    await launchAtStartup.enable();
                  } else {
                    await launchAtStartup.disable();
                  }
                  setState(() {});
                },
              );
            },
          ),
        ],
        CheckboxListTile(
          value: devModeEnabled,
          title: Text('Dev Mode enabled'),
          subtitle: Text(
            'When enabled, more debug information and tools are shown.',
          ),
          onChanged: (val) {
            dataBox.put('dev_mode_enabled', val!);

            setState(() {});
          },
        ),
      ],
    );
  }
}
